# Scalable BLAST Search 
Solution consist of [sequenceserver-scale](https://github.com/zhxu73/sequenceserver-scale), [blast-workqueue](https://github.com/zhxu73/blast-workqueue), and deployment script (in this repo)

## Deploy Using Script (only)
The main deployment method is through script, Cyverse Atmosphere(Deployment Script), DigitalOcean(user data), Linode(Stackscript) all provide a way to use script to deploy instances.

### Instructions for Cyverse Atmosphere:

https://wiki.cyverse.org/wiki/pages/viewpage.action?pageId=47120572

### If your platform does not support deploy instances with a script through its dashboard or control panel, then you can also run the script manually after ssh into the instances

Deploy Web Instance:
https://github.com/JLHonors/ACIC2019-Midterm/blob/master/deploy/deploy_web_instance.sh

`./depoly_web_instance.sh`

Deploy Worker Instance:
https://github.com/JLHonors/ACIC2019-Midterm/blob/master/deploy/deploy_worker_instance.sh
`./depoly_worker_instance.sh`


