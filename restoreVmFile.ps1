<#
This script loops through a feeder txt file with one VM per line and restores a specified file in place for all VM's
If using domain credentials then use format user@domain.example
Create folder C:\cvscripts and run script from this folder
Change the @body fileoption and destination sections to specify the file to be restored
Change the @body guestUserPassword. Convert your password to base64. You can use https://base64.guru/converter
Recommend generating the JSON via the Command Center Equivalent API option then using below as a reference for variable replacement
Yes I know!! The script has too many manual steps and could be improved.
#>

# Setup logging
$Logfile = "C:\cvscripts\restoreVmFile.log"

# Get list of VM's from file
$vms = Get-Content -path C:\cvScripts\vmlist.txt

# Specify the client name for the HyperVisor here. NOTE: This is not the hostname of the VCenter server but rather the client name as defined in Commvault.
$hypervisor = 'ESX2'

$cs = "https://commserve1.cv.lab"

function WriteLog
{

    Param ([string]$LogString)
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage

}


# Let's get credentials from the user to login to Commvault. Needs to be an admin
$credential = Get-Credential
$username = $credential.UserName
$password = $credential.GetNetworkCredential().password

# password needs to be in base64 format
$password = [System.Text.Encoding]::UTF8.GetBytes($password)
$password = [System.Convert]::ToBase64String($password)

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/json")
$headers.Add("Content-Type", "application/json")
$body = "{`n  `"password`": `"$password`",`n  `"username`": `"$username`",`n  `"timeout`" : 30`n}"

# Login
$response = Invoke-RestMethod "$cs/webconsole/api/Login" -Method 'POST' -Headers $headers -Body $body

# need to extract the token
$token = $response | Select-Object -ExpandProperty token
# the first five characters need to be removed to get just the token
$token = $token.substring(5)

# Now that we have a token we can do things
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/json")
$headers.Add("Authtoken", "$token")
$headers.Add("Content-Type", "application/json")

# Get list of VM's in CommCell
$ccVms = Invoke-RestMethod "$cs/webconsole/api/VM" -Method 'GET' -Headers $headers


foreach ($vm in $vms) {
    # Get the values from each line in the csv file

   # $vm
    # Get GUID for VM
    $vmGuid = $ccVMs.vmStatusInfoList | Where-Object name -eq $vm | Select-Object -ExpandProperty strGUID

    if ($null -ne $vmGuid) {
        
        # Specify JSON here so can input variables.
        $body = @"
        {
            "taskInfo": {
            "task": {
                "taskFlags": {
                "disabled": false
                },
                "policyType": "DATA_PROTECTION",
                "taskType": "IMMEDIATE",
                "initiatedFrom": "GUI",
                "ownerName": "Administrator"
            },
            "associations": [
                {
                "subclientId": 131,
                "client": {},
                "applicationId": 106,
                "_type_": "CLIENT_ENTITY"
                }
            ],
            "subTasks": [
                {
                "subTask": {
                    "subTaskName": "",
                    "subTaskType": "RESTORE",
                    "operationType": "RESTORE"
                },
                "options": {
                    "restoreOptions": {
                    "browseOption": {
                        "commCellId": 2,
                        "timeRange": {
                        "fromTime": 0,
                        "toTime": 0
                        },
                        "noImage": true,
                        "useExactIndex": false,
                        "mediaOption": {
                        "copyPrecedence": {
                            "copyPrecedence": 0
                        }
                        },
                        "listMedia": false,
                        "toTime": 0,
                        "fromTime": 0,
                        "showDeletedItems": false
                    },
                    "destination": {
                        "destPath": [
                        "C:\\RESTORE_TEST"
                        ],
                        "destClient": {
                        "clientId": 2,
                        "clientName": "commserve1"
                        },
                        "inPlace": false,
                        "isLegalHold": false
                    },
                    "restoreACLsType": "ACL_DATA",
                    "volumeRstOption": {
                        "volumeLeveRestore": false
                    },
                    "virtualServerRstOption": {
                        "diskLevelVMRestoreOption": {
                        "useVcloudCredentials": true
                        },
                        "isFileBrowse": true,
                        "viewType": "DEFAULT",
                        "fileLevelVMRestoreOption": {
                        "serverName": "$hypervisor",
                        "vmGuid": "$vmGuid",
                        "vmName": "$vm",
                        "guestUserPassword": {
                            "userName": "$vm\\administrator",
                            "password": "Q81tbTZhdRx0INI="
                        }
                        },
                        "vCenterInstance": {
                        "instanceId": 14,
                        "applicationId": 106,
                        "clientId": 16,
                        "clientName": "$hypervisor"
                        }
                    },
                    "fileOption": {
                        "sourceItem": [
                        "\\$vmGuid\\C\\ProgramData\\Commvault Systems\\Galaxy\\LogFiles\\Install.log"
                        ]
                    },
                    "impersonation": {
                        "useImpersonation": false,
                        "user": {
                        "userName": ""
                        }
                    },
                    "commonOptions": {
                        "overwriteFiles": true,
                        "detectRegularExpression": true,
                        "unconditionalOverwrite": true,
                        "stripLevelType": "PRESERVE_LEVEL",
                        "preserveLevel": 1,
                        "stripLevel": 0,
                        "restoreACLs": true,
                        "isFromBrowseBackup": true,
                        "clusterDBBackedup": false
                    }
                    },
                    "adminOpts": {
                    "updateOption": {
                        "invokeLevel": "NONE"
                    }
                    },
                    "commonOpts": {
                    "subscriptionInfo": "<Api_Subscription subscriptionId =\"1444\"/>",
                    "notifyUserOnJobCompletion": false
                    }
                }
                }
            ]
            }
        }
"@
        
        # Restore VM
        $response = Invoke-RestMethod "$cs/webconsole/api/CreateTask" -Method 'POST' -Headers $headers -Body $body -ContentType 'application/json'
        
        # Get job id
        $jobid = $response | Select-Object -ExpandProperty jobIds

        # Write output
        Write-Host "VM: $vm with $vmGuid in-place file restore started with JobID: $jobid"
        WriteLog "VM: $vm with $vmGuid in-place restore started with JobID: $jobid"

    } else {
        #$vm
        Write-Host "VM: $vm not found in CommCell"
        WriteLog "VM: $vm not found in CommCell"

    }

}