package encoding

import (
	"errors"
	"strings"
	"unicode/utf8"

	"github.com/mushroomsir/iconv"
	"github.com/saintfish/chardet"
)

func DetectCharset(content []byte) (string, error) {
	detector := chardet.NewTextDetector()
	result, err := detector.DetectBest(content)
	if err != nil {
		return "", err
	}

	return strings.ToUpper(result.Charset), nil
}

func ToUTF8(content []byte, ignoreInvalidITF8Chars ...bool) (string, error) {
	ignore := false
	if len(ignoreInvalidITF8Chars) > 0 {
		ignore = ignoreInvalidITF8Chars[0]
	}

	cs, err := DetectCharset(content)
	if err != nil {
		if !ignore {
			return "", err
		}
		cs = "UTF-8"
	}

	bs := string(content)
	if ignore {
		if !utf8.ValidString(bs) {
			v := make([]rune, 0, len(bs))
			for i, r := range bs {
				if r == utf8.RuneError {
					_, size := utf8.DecodeRuneInString(bs[i:])
					if size == 1 {
						continue
					}
				}
				v = append(v, r)
			}
			bs = string(v)
		}
	}

	if cs == "UTF-8" {
		return bs, nil
	}

	converter, err := iconv.NewConverter(cs, "UTF-8")
	if err != nil {
		err = errors.New("Failed to convert " + cs + " to UTF-8: " + err.Error())
		return bs, err
	}

	return converter.ConvertString(bs)
}
