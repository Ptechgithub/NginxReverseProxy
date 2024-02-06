# NGINX Reverse Proxy Installer

## Install
```
bash <(curl -fsSL https://raw.githubusercontent.com/Ptechgithub/NginxReverseProxy/main/install.sh)
```
![20](https://github.com/Ptechgithub/configs/blob/main/media/20.jpg)

---

این اسکریپت Bash برای نصب و پیکربندی NGINX Reverse Proxy بر روی سرورهای لینوکسی استفاده می‌شود. با اجرای این اسکریپت، می‌توانید به سرعت و به صورت خودکار یک سرور وب را به عنوان یک پروکسی برای مسیردهی ترافیک به برنامه‌های دیگر (مانند سرویس‌های GRPC و WebSocket) پیکربندی کنید.

## استفاده

پس از اجرای اسکریپت، دامنه‌ی مورد نظر خود را وارد کنید و مراحل نصب را دنبال کنید. اسکریپت SSL certificate را برای دامنه‌ی شما دریافت خواهد کرد و تنظیمات NGINX Reverse Proxy را اعمال می‌کند.
و در نهایت به شما مسیر سرتیفیکت را میدهد. که میتوانید در پنل خودتون استفاده کنید.
در این اسکریپت `Path` را خودتان انتخاب می‌کنید.
برای استفاده در پنل `x-ui` تنها کافیست به صورت زیر برای grpc و ws اقدام کنید.