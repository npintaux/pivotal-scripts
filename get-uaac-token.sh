#!/bin/bash
  
#
# retrieve your token from the existing uaac
#
token=$(uaac contexts | grep "access_token" | awk {'print $2'})
uaacTokenString="Authorization: Bearer $token"
echo
echo $uaacTokenString
echo

