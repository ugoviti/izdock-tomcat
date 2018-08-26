# How to use this image

```docker pull izdock/tomcat```

```docker run -it --rm izdock/tomcat```

You can test it by visiting http://container-ip:8080 in a browser

If you need access outside the host, on port 8888:
```docker run -it --rm -p 8888:8080 izdock/tomcat```

You can then go to http://localhost:8888 or http://host-ip:8888 in a browser.

Ovverride Config Directory:
```docker run -it --rm -p 8080:8080 -e APP_ADMIN_USERNAME=tomcatadmin -e APP_ADMIN_PASSWORD=VeryStrong3ndSecurePWD -e APP_HOME=/data -v /tmp/tomcat:/data izdock/tomcat```

Example Usable Override Variables:
```
ENV APP_HOME              "/data"
ENV APP_HTTP_PORT         8080
ENV APP_AJP_PORT          8009
ENV APP_SHUTDOWN_PORT     8005
ENV APP_REMOTE_MANAGEMENT 1
ENV APP_ADMIN_USERNAME    "manager"
ENV APP_ADMIN_PASSWORD    ""
```

