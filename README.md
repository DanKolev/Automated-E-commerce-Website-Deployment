# Automated deployment of an e-commerce web site

This Bash script deploys an [e-commerce website](https://github.com/jacob5412/PHP-ecommerce) on a single server.

- This script was developed and tested on Rocky Linux 8 with graphical mode enabled.

To run:
- Download the e-commerce_website_deployment.sh file
- Go to the same folder the file is located. Type ```sudo ./e-commerce_website_deployment```
- To view the deployed web site, open a web browser and type ```localhost``` or ```http://127.0.0.1```

## Features

- Prints status messages in color.
- Checks the status of a service. Error and exit if not active.
- Checks status and displays if ports are enabled/disbaled in the firwalld rule.
- Checks if item is present on the web page.

## Security basics
Updates:
- System updates have been configured to download and install automatically

Apache Server:
- hide version number of Apache Server
- disable directory browsder listing

SSH:
- default port is changed from 22 to 3322
- root and empty password login is disabled
- key-based authentication can be enabled. This line is currently commented because key have not yet been generated.
- limit users accessing the server on per username basis

MariaDB:
- default port is changed from 3306 to 4406
- SSL certificates can be used, however this is beyond the scope of the automation exercise.

Fail2Ban:
- Fail2ban is an intrusion prevention software framework.
- Fail2ban is configured to monitor access for SSH and MariaDB.
# Automated-E-commerce-Website-Deployment
