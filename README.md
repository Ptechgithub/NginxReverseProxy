# NGINX Reverse Proxy Installer

## Install
```
bash <(curl -fsSL https://raw.githubusercontent.com/Ptechgithub/NginxReverseProxy/main/install.sh)
```
![20](https://github.com/Ptechgithub/configs/blob/main/media/20.jpg)

---

این اسکریپت Bash برای نصب و پیکربندی NGINX Reverse Proxy بر روی سرورهای لینوکسی استفاده می‌شود. با اجرای این اسکریپت، می‌توانید به سرعت و به صورت خودکار یک سرور وب را به عنوان یک پروکسی برای مسیردهی ترافیک به برنامه‌های دیگر (مانند سرویس‌های GRPC و WebSocket) پیکربندی کنید.

---
## استفاده
ابتدا در CDN خود مثلا Cloudflare یک A record بسازید و آی پی سرور را به دامین یا ساب دامین خود اشاره بدید و تیک پروکسی هم روشن کنید.

2) در بخش تنظیمات Network تیک گزینه ی GRPC را فعال کنید. 

در بخش SSL/TLS encryption mode گزینه ی Full را انتخاب کنید.
پس از اجرای اسکریپت، دامنه‌ی مورد نظر خود را وارد کنید و مراحل نصب را دنبال کنید.
اسکریپت برای دامنه‌ی شما `SSL certificate` را  دریافت خواهد کرد و تنظیمات NGINX Reverse Proxy را اعمال می‌کند.
و در نهایت به شما مسیر سرتیفیکت را میدهد. که میتوانید در پنل خود استفاده کنید.
در این اسکریپت `Path` را خودتان انتخاب می‌کنید.
برای استفاده در پنل `x-ui` تنها کافیست به صورت زیر برای grpc و ws اقدام کنید:

---