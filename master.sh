#!/usr/bin/bash
function pingtest
{
 echo -n -e "\e[33mEnter Server Name:\e[0m"
 read selection
 SSH=`nmap --system-dns -p22 $selection | egrep -w "open|closed"| awk '{print $2}'`
 /usr/bin/ping -c 3 $selection > /dev/null
 Result=`echo $?`
 if [[ $Result == 0 ]]
 then
  echo -e "\e[32mServer is reachable through ping\e[0m"
  sleep 2
  if [[ $SSH == open ]]
  then
   echo -e "\e[32mssh port 22 is Listening as expected\e[0m"
   sleep 2
  else
   echo -e "\e[31mssh port 22 is not Listening, please check sshd service status from console\e[0m"
   sleep 2
  fi
 else
  echo -e "\e[31mServer not reachable Further Troubleshooting required\e[0m"
  sleep 2
 fi;
}
function userstatus
{
 sleep 1
 echo -n -e "\e[33mEnter User/User-id Name: \e[0m"
 read user
 id $user > /dev/null 2>&1
 Result=`echo $?`
 if [[ $Result == 0 ]]
 then
  sleep 1
  echo -e "\e[32mUser exists...Checking for Account lock and blank password\e[0m"
  sleep 1  
 else
  sleep 1
  echo -e "\e[31mUser doesn't exist on this server\e[0m" && exit 0
  sleep 1
 fi
 Shells1=`cat /etc/passwd | grep -w ^$user | cut -d ":" -f 7`
 Shells2=`cat /etc/shells | grep $Shells1`
 SystemShells=`echo $?`
 BlankPasswd=`awk -F":" '($2 == "!!" || $2 == "*") {print $1}' /etc/shadow | grep -w $user`
 PasswdExpiredPam=`pam_tally2 --user=$user | awk '{print $2}'|grep -o -E '[0-9]+'`  
 PasswdExpiredChage=`/usr/bin/chage -l $user | grep "Password expires"| awk -F ": " '{print $2}'`
 if [[ $SystemShells == 0 ]]
 then
  echo -e "\e[32mUser has a valid shell\e[0m"
  sleep 1
 else
  echo -e "\e[31mUser not holding valid login shell, current shell is $Shells1\e[0m"
  sleep 1
 fi
 if [[ $BlankPasswd == $user ]]
 then
  echo -e "\e[31mUser having blank password, that is a security risk. Check with user before setting the password\e[0m" && return
  sleep 1
 else
  echo -e "\e[32mUser has a non-blank password. That is good!!!\e[0m"
  sleep 1
 fi
 cat /etc/ssh/sshd_config | egrep "^AllowUsers|^AllowGroups" > /dev/null
 ssh_allow=$?
 cat /etc/ssh/sshd_config | egrep "^DenyUsers|^DenyGroups" > /dev/null
 ssh_deny=$?
 if [[ $ssh_allow -eq 0 || $ssh_deny -eq 0 ]]
 then
  echo -n -e "\e[33msshd level restrictions in place for this system. \e[0m"
  sleep 1
  echo -e "\e[33mChecking for this particular user\e[0m"
  sleep 1
  cat /etc/ssh/sshd_config | egrep "^AllowUsers" | grep -w $user > /dev/null
  user_ssh_allow=$?
  for group in `groups $user | awk -F ":" '{print $2}' | xargs -n 1`
  do
  cat /etc/ssh/sshd_config | grep "^AllowGroups" | grep -w $group > /dev/null
  done
  group_ssh_allow=$?
  cat /etc/ssh/sshd_config | egrep "^DenyUsers" | grep -w $user > /dev/null
  user_ssh_deny=$?
  for group in `groups $user | awk -F ":" '{print $2}' | xargs -n 1`
  do
  cat /etc/ssh/sshd_config | grep "^DenyGroups" | grep -w $group > /dev/null
  done
  group_ssh_deny=$?
  if [[ $user_ssh_allow == 0 || $group_ssh_allow == 0 ]] && [[ $user_ssh_deny == 1 || $group_ssh_deny == 1 ]]
  then
   echo -e "\e[32mUser is allowed ssh access\e[0m"
   sleep 1
  else
   echo -e "\e[31muser is denied ssh access. Request him/her to check with server owner for access\e[0m"
   sleep 1
  fi
 else 
  echo -e "\e[32msshd level restrictions are not in place for this system. Checking further...\e[0m"
 sleep 1
 fi 
 if [[ $PasswdExpiredPam == 0 ]]
 then
  echo -e "\e[32mUser Account is not Locked at pam. Checking further...\e[0m"
  sleep 1
 else
  echo -n -e "\e[31mUser Account is locked at pam and required reset,do you want to continue - \e[0mYes or No: \e[0m"
  sleep 1
  read Option
  if [[ $Option == [Y,y]es ]]
  then
   echo -e "\e[33mUnlocking the Account\e[0m"
   sleep 1
  pam_tally2 --user=$user --reset > /dev/null 2>&1
  else
   echo -e "\e[31mPassword Reset request denied by Requester\e[0m"
   sleep 1
  fi
 fi
 if [[ $PasswdExpiredChage == "password must be changed" ]]
 then
  echo -n -e "\e[31mUser password expired due to aging and required reset,do you want to continues - \e[0mYes or No: \e[0m"
  read Option
  if [[ $Option == [Y,y]es ]]
  then 
   echo "Sample123" | passwd --stdin $user > /dev/null 2>&1
   /usr/bin/passwd -e $user > /dev/null 2>&1
   sleep 1
   echo -e "\e[32mPassword reset done,please share the new password as \e[31mSample123\e[0m \e[32mwith requested secured way\e[0m"
   sleep 1
  else
   echo -e "\e[31mPassword Reset request denied by Requester\e[0m"
   sleep 1
  fi
 else
  echo -e "\e[32mUser Account is not locked due to aging. Checking further...\e[0m"
  sleep 1
 fi
 function CheckShadowLock
 {
  if [[ `cat /etc/shadow | grep -w $1 | cut -d ":" -f 2` == '!!'* ]]
  then return 99
  else
   if [[ `cat /etc/shadow | grep -w $1 | cut -d ":" -f 2` == '!'* ]]
   then return 98
   fi
  fi
 }
 CheckShadowLock $user
 PasswdExpiredShadow=`echo $?`
 if [[ PasswdExpiredShadow -eq 99 ]]
 then
  echo -n -e "\e[31mUser password is locked at system files and required reset,do you want to continues - \e[0mYes or No : \e[0m"
  read Option
  if [[ $Option == [Y,y]es ]]
  then
   sleep 1
   echo -e "\e[33munlocking the Password\e[0m"
   sleep 1
   passwd -u $user > /dev/null 2>&1
  else
   echo -e "\e[31mPassword Reset request denied by Requester\e[0m"
   sleep 1
  fi
 else
 echo -e "\e[32mUser Password is not locked due to system files. Checking further...\e[0m"
 sleep 1
 fi
 if [[ PasswdExpiredShadow -eq 98 ]]
 then
  echo -n -e "\e[31mUser Account is locked at shadow file and required reset,do you want to continues - \e[0mYes or No : \e[0m"
  read Option
  if [[ $Option == [Y,y]es ]]
  then
   echo -e "\e[33munlocking the Account\e[0m"
   sleep 1
   usermod -U $user > /dev/null 2>&1
  else
   echo -e "\e[31mAccount Reset request denied by Requester\e[0m"
   sleep 1
  fi
 else
  echo -e "\e[32mUser Account is not locked due to system files\e[0m"
  sleep 1
 fi
}
function sudocheck
{
 sleep 1
 echo -n -e "\e[33mEnter User/User-id Name: \e[0m"
 read user
 id $user > /dev/null 2>&1
 Result=`echo $?`
 if [[ $Result == 0 ]]
 then
  sleep 1
  echo -e "\e[32mUser exists...Checking for Admin access status\e[0m"
  sleep 1  
  sudoresult=`sudo -l -U $user | grep -A 1 User | grep not`
  if [[ $sudoresult ]]
  then
   echo -e "\e[31m`sudo -l -U $user | grep -A 1 User`\e[0m"
   sleep 1
  else
   echo -e "\e[32m`sudo -l -U $user | grep -A 1 User`\e[0m"
  sleep 1
  fi
 else
  sleep 1
  echo -e "\e[31mUser doesn't exist on this server\e[0m" && return
  sleep 1
 fi
}
function servicecheck
{
 echo -n -e "\e[33mEnter Service name to check:\e[0m"
 read selection
 echo -n -e "\e[33mChecking the service status...\e[0m"
 sleep 1
 service $selection status
 servicestatus=$?
 if [[ $servicestatus == 0 ]]
 then
  echo -e "\e[32mService $selection is running fine\e[0m"
 elif [[ $servicestatus == 3 ]]
 then
  echo -n -e "\e[33mService $selection is stopped. Do you want to start ? - \e[0mYes or No: \e[0m" 
  sleep 1
  read Option
  if [[ $Option == [Y,y]es ]]
  then
   service $selection start
   service $selection status
   servicestatus=$?
   if [[ $servicestatus == 0 ]]
   then
    echo -e "\e[32mService $selection started successfully\e[0m"
   else
    echo -e "\e[31mStarting of Service $selection failed. Please check system logs\e[0m"
   fi
  else
   echo -e "\e[33mService start denied by Requester\e[0m"
   sleep 1
  fi
 elif [[ $servicestatus == 4 ]]
 then
  echo -e "\e[31mService $selection not available in this server \e[0m" 
  sleep 1
 fi
}
function fscheck
{
 echo "Below filesystems crossed 45% threshold"
 echo "======================================="
 df -h | egrep -v "Filesystem|tmpfs|sr" | awk '{print $5,$6}' | awk -F"% " '$1>45 {print $2}'
 sleep 1
 for i in `df -h | egrep -v "Filesystem|tmpfs|sr" | awk '{print $5,$6}' | awk -F"% " '$1>45 {print $2}'`
 do
 echo "Please find below the big files in FileSystem $i"
 echo "======================================================="
 find $i -size +2M -exec ls -l {} \; | sort +4 -5rn |more
 echo
 done
}
function cpucheck
{
 sleep 1
 echo "Current CPU usage % is:" `top -b -n1 | grep "Cpu(s)" | awk '{print $2 + $4}'`
 sleep 1
 echo "Top 10 CPU utilizing processes are in below order"
 echo "================================================="
 sleep 1
 ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head 
 sleep 1
}
function memcheck
{
 FREE_DATA=`free -m | grep Mem` 
 CURRENT=`echo $FREE_DATA | cut -f3 -d' '`
 TOTAL=`echo $FREE_DATA | cut -f2 -d' '`
 sleep 1
 echo "Current Memory usage % is:" $(echo "scale = 2; $CURRENT/$TOTAL*100" | bc)
 sleep 1
 echo "Top 10 Memory utilizing processes are in below order"
 echo "===================================================="
 sleep 1
 ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head
 sleep 1
}
function exit
{
break
}
echo -e "*******************************************************************************************************"
echo -e "** This Script is Private Property Of T-Systems INDIA,Copy Right is strictly prohibited.             **"
echo -e "** Script Usage:-  This Script is used for checking the Server access and User login                 **"
echo -e "** Here are the script Options:-                                                                     **"
echo -e "**     1 - Server Status                                                                             **"
echo -e "**         -----> This option includes checking Network connectivity, SSH Service status and         **"
echo -e "**                uptime of the Remote client                                                        **"
echo -e "**     2 - User Status                                                                               **"
echo -e "**         -----> This option includes checking Account Lock, password expire,                       **"
echo -e "**                validity of login shell and if a blank Password.                                   **"
echo -e "**     3 - Sudo access status                                                                        **"
echo -e "**         -----> This option is to check the affected account/user Privilege                        **"
echo -e "**     4 - Service status                                                                            **"              
echo -e "**         -----> This option is to check th status of provided service and to start same optionally **"
echo -e "**     5 - Filesystem Usage                                                                          **"
echo -e "**         -----> This option is to check the over threshold Filesystems and the big files in them   **"
echo -e "**     6 - CPU usage                                                                                 **"
echo -e "**         -----> This option is to check the CPU usage % and top CPU utilizing processes            **"
echo -e "**     7 - Memory Usage                                                                              **"
echo -e "**         -----> This option is to check the Memory usage % and top memory utilizing processes      **"  
echo -e "*******************************************************************************************************"
userid=`/usr/bin/whoami`
if [[ $userid == root ]]
then
 echo -e "\e[32mWelcome Root, Please select one of the menu into Choice\e[0m"
 sleep 1
else
 echo -e "\e[33mPlease run as root/admin privilage\e[0m" && exit 0
fi
while true
do
 echo
 echo "Menu"
 echo "----"
 echo
 echo "1 - Checking Network connectivity,sshd service status"
 echo "2 - User Account status"
 echo "3 - User Admin access Information"
 echo "4 - Service status"
 echo "5 - Exceeded Filesystems usage status"
 echo "6 - CPU Usage statistics"
 echo "7 - Memory Usage statistics"
 echo "8 - Exit"
 echo
 echo -n "Enter Choice: "
 read selection
 case $selection in
  1) pingtest;;
  2) userstatus;;
  3) sudocheck;;
  4) servicecheck;;
  5) fscheck;;
  6) cpucheck;;
  7) memcheck;;
  8) exit
 esac
done