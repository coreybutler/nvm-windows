package web

import (
	"crypto/tls"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"nvm/arch"
	"nvm/file"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"archive/zip"

	"github.com/blang/semver"
	fs "github.com/coreybutler/go-fsutil"
)

var client = &http.Client{}
var nodeBaseAddress = "https://nodejs.org/dist/"
var npmBaseAddress = "https://github.com/npm/cli/archive/"

// var oldNpmBaseAddress = "https://github.com/npm/npm/archive/"

func SetProxy(p string, verifyssl bool) {
	if p != "" && p != "none" {
		proxyUrl, _ := url.Parse(p)
		client = &http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxyUrl), TLSClientConfig: &tls.Config{InsecureSkipVerify: verifyssl}}}
	} else {
		client = &http.Client{Transport: &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: verifyssl}}}
	}
}

func SetMirrors(node_mirror string, npm_mirror string) {
	if node_mirror != "" && node_mirror != "none" {
		nodeBaseAddress = node_mirror
		if strings.ToLower(nodeBaseAddress[0:4]) != "http" {
			nodeBaseAddress = "http://" + nodeBaseAddress
		}
		if !strings.HasSuffix(nodeBaseAddress, "/") {
			nodeBaseAddress = nodeBaseAddress + "/"
		}
	}
	if npm_mirror != "" && npm_mirror != "none" {
		npmBaseAddress = npm_mirror
		if strings.ToLower(npmBaseAddress[0:4]) != "http" {
			npmBaseAddress = "http://" + npmBaseAddress
		}
		if !strings.HasSuffix(npmBaseAddress, "/") {
			npmBaseAddress = npmBaseAddress + "/"
		}
	}
}

func GetFullNodeUrl(path string) string {
	return nodeBaseAddress + path
}

func GetFullNpmUrl(path string) string {
	return npmBaseAddress + path
}

func IsLocalIPv6() (bool, error) {
	conn, err := net.Dial("tcp", "[::1]:80")
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "no connection") {
			return false, nil
		}

		return false, err
	}
	defer conn.Close()

	return true, nil
	// addrs, err := net.InterfaceAddrs()
	// if err != nil {
	// 	return false, err
	// }

	// for _, addr := range addrs {
	// 	fmt.Println(addr.String())
	// 	if strings.Contains(addr.String(), ":") {
	// 		return true, nil
	// 	}
	// }

	// return false, nil
}

// Returns whether the address can be pinged and whether it is using IPv6 or not
func Ping(url string) bool {
	req, err := http.NewRequest("HEAD", url, nil)
	if err != nil {
		fmt.Println(err)
		return false
	}

	req.Header.Set("User-Agent", "NVM for Windows")

	response, err := client.Do(req)
	if err != nil {
		return false
	}

	if response.StatusCode == 200 {
		return true
	}

	return false
}

func Download(url string, target string, version string) bool {
	output, err := os.Create(target)
	if err != nil {
		fmt.Println("Error while creating", target, "-", err)
		return false
	}
	defer output.Close()

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		fmt.Println(err)
		return false
	}

	// TODO: Add version to user agent
	req.Header.Set("User-Agent", "NVM for Windows")

	response, err := client.Do(req)
	if err != nil {
		fmt.Println("Error while downloading", url, "-", err)
		return false
	}
	defer response.Body.Close()
	c := make(chan os.Signal, 2)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		fmt.Println("Download interrupted. Rolling back...")
		output.Close()
		response.Body.Close()
		var err error
		if strings.Contains(target, "node") {
			err = os.RemoveAll(os.Getenv("NVM_HOME") + "\\v" + version)
		} else {
			err = os.Remove(target)
		}
		if err != nil {
			fmt.Println("Error while rolling back", err)
		}
		os.Exit(1)
	}()
	var body []byte
	if response.StatusCode != 200 {
		body, err = ioutil.ReadAll(response.Body)
		if err != nil {
			fmt.Println("Failed to read response body: " + err.Error())
		}
	} else {
		_, err = io.Copy(output, response.Body)
		if err != nil {
			fmt.Println("Error while downloading", url, "-", err)
		}
	}

	redirect := response.Header.Get("Location")

	switch response.StatusCode {
	case 300:
		if len(redirect) > 0 && redirect != url {
			return Download(redirect, target, version)
		}

		if strings.Contains(url, "/npm/cli/archive/v6.14.17.zip") {
			return Download("https://github.com/npm/cli/archive/refs/tags/v6.14.17.zip", target, version)
		}

		fmt.Printf("\n\nREMOTE SERVER FAILURE\n\n---\nGET %v --> %v\n\n", url, response.StatusCode)
		for key, val := range response.Header {
			fmt.Printf("%v: %v\n", key, val)
		}
		if len(body) > 0 {
			fmt.Printf("\n%s", body)
		}
		fmt.Println("\n---\n\n")

		return false
	case 302:
		fallthrough
	case 307:
		fmt.Println("Redirecting to " + redirect)
		return Download(redirect, target, version)
	case 200:
		// No processing necessary for successful response
	default:
		fmt.Println("Download failed. Rolling Back.")
		err := os.Remove(target)
		if err != nil {
			fmt.Println(target)
			fmt.Println("Rollback failed.", err)
		}
		return false
	}

	return true
}

func GetNodeJS(root string, v string, a string, append bool) bool {
	a = arch.Validate(a)

	vpre := ""
	vers := strings.Fields(strings.Replace(v, ".", " ", -1))
	main, _ := strconv.ParseInt(vers[0], 0, 0)

	if a == "32" {
		if main > 0 {
			vpre = "win-x86/"
		} else {
			vpre = ""
		}
	} else if a == "64" {
		if main > 0 {
			vpre = "win-x64/"
		} else {
			vpre = "x64/"
		}
	} else if a == "arm64" {
		if main > 0 {
			vpre = "win-arm64/"
		} else {
			vpre = "arm64/"
		}
	}

	url := getNodeUrl(v, vpre, a, append)

	if url == "" {
		//No url should mean this version/arch isn't available
		fmt.Println("Node.js v" + v + " " + a + "bit isn't available right now.")
	} else {
		fileName := root + "\\v" + v + "\\node" + a + ".exe"
		if strings.HasSuffix(url, ".zip") {
			fileName = root + "\\v" + v + "\\node.zip"
		}

		fmt.Println("Downloading node.js version " + v + " (" + a + "-bit)... ")

		if Download(url, fileName, v) {
			// Extract the zip file
			if strings.HasSuffix(url, ".zip") {
				fmt.Println("Extracting node and npm...")
				err := unzip(fileName, root+"\\v"+v)
				if err != nil {
					fmt.Println("Error extracting from Node archive: " + err.Error())

					err = os.Remove(fileName)
					if err != nil {
						fmt.Printf("Failed to remove %v after failed extraction. Please remove manually.", fileName)
					}

					return false
				}

				err = os.Remove(fileName)
				if err != nil {
					fmt.Printf("Failed to remove %v after successful extraction. Please remove manually.", fileName)
				}

				zip := root + "\\v" + v + "\\" + strings.Replace(filepath.Base(url), ".zip", "", 1)
				err = fs.Move(zip, root+"\\v"+v, true)
				if err != nil {
					fmt.Println("ERROR moving file: " + err.Error())
				}

				err = os.RemoveAll(zip)
				if err != nil {
					fmt.Printf("Failed to remove %v after successful extraction. Please remove manually.", zip)
				}
			}
			fmt.Println("Complete")
			return true
		} else {
			return false
		}
	}
	return false

}

func GetNpm(root string, v string) bool {
	url := GetFullNpmUrl("v" + v + ".zip")
	// temp directory to download the .zip file
	tempDir := root + "\\temp"

	// if the temp directory doesn't exist, create it
	if !file.Exists(tempDir) {
		fmt.Println("Creating " + tempDir + "\n")
		err := os.Mkdir(tempDir, os.ModePerm)
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
	}
	fileName := tempDir + "\\" + "npm-v" + v + ".zip"

	fmt.Printf("Downloading npm version " + v + "... ")
	if Download(url, fileName, v) {
		fmt.Printf("Complete\n")
		return true
	} else {
		return false
	}
}

func GetRemoteTextFile(url string) string {
	response, httperr := client.Get(url)
	if httperr != nil {
		fmt.Println("\nCould not retrieve " + url + ".\n\n")
		fmt.Printf("%s", httperr)
		os.Exit(1)
	}

	if response.StatusCode != 200 {
		fmt.Printf("Error retrieving \"%s\": HTTP Status %v\n", url, response.StatusCode)
		os.Exit(0)
	}

	defer response.Body.Close()

	contents, readerr := ioutil.ReadAll(response.Body)
	if readerr != nil {
		fmt.Printf("%s", readerr)
		os.Exit(1)
	}

	return string(contents)
}

func IsNode64bitAvailable(v string) bool {
	if v == "latest" {
		return true
	}

	// Anything below version 8 doesn't have a 64 bit version
	vers := strings.Fields(strings.Replace(v, ".", " ", -1))
	main, _ := strconv.ParseInt(vers[0], 0, 0)
	minor, _ := strconv.ParseInt(vers[1], 0, 0)
	if main == 0 && minor < 8 {
		return false
	}

	// TODO: fixme. Assume a 64 bit version exists
	return true
}

func IsNodeArm64bitAvailable(v string) bool {
	if v == "latest" {
		return true
	}

	// Anything below version 19.9 doesn't have a arm64 bit version
	vers := strings.Fields(strings.Replace(v, ".", " ", -1))
	main, _ := strconv.ParseInt(vers[0], 0, 0)
	minor, _ := strconv.ParseInt(vers[1], 0, 0)
	fmt.Println("main "+ strconv.FormatInt(main,10) + " minor "+strconv.FormatInt(minor,10))
	if main < 19 {
		return false
	}
	if main == 19 && minor < 9{
		return false
	}
	
	// TODO: fixme. Assume a 64 bit version exists
	return true
}

func getNodeUrl(v string, vpre string, arch string, append bool) string {
	a := "x86"
	if arch == "arm64" {
		a = "arm64"
	}
	if arch == "64" {
		a = "x64"
	}

	//url := "http://nodejs.org/dist/v"+v+"/" + vpre + "/node.exe"
	url := GetFullNodeUrl("v" + v + "/" + vpre + "/node.exe")

	if !append {
		version, err := semver.Make(v)
		if err != nil {
			fmt.Println("Node.js v" + v + " " + a + "bit isn't available right now.")
			fmt.Println(err.Error())
			os.Exit(1)
		}

		corepack, _ := semver.Make("16.9.0")

		if version.GTE(corepack) {
			url = GetFullNodeUrl("v" + v + "/node-v" + v + "-win-" + a + ".zip")
		}
	}

	// Check online to see if a 64 bit version exists
	_, err := client.Head(url)
	if err != nil {
		return ""
	}
	return url
}

func unzip(src, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer func() {
		if err := r.Close(); err != nil {
			panic(err)
		}
	}()

	os.MkdirAll(dest, 0755)

	// Closure to address file descriptors issue with all the deferred .Close() methods
	extractAndWriteFile := func(f *zip.File) error {
		rc, err := f.Open()
		if err != nil {
			return err
		}
		defer func() {
			if err := rc.Close(); err != nil {
				panic(err)
			}
		}()

		path := filepath.Join(dest, f.Name)

		// Check for ZipSlip (Directory traversal)
		if !strings.HasPrefix(path, filepath.Clean(dest)+string(os.PathSeparator)) {
			return fmt.Errorf("illegal file path: %s", path)
		}

		if f.FileInfo().IsDir() {
			os.MkdirAll(path, f.Mode())
		} else {
			os.MkdirAll(filepath.Dir(path), f.Mode())
			f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
			if err != nil {
				return err
			}
			defer func() {
				if err := f.Close(); err != nil {
					panic(err)
				}
			}()

			_, err = io.Copy(f, rc)
			if err != nil {
				return err
			}
		}
		return nil
	}

	for _, f := range r.File {
		err := extractAndWriteFile(f)
		if err != nil {
			return err
		}
	}

	return nil
}
