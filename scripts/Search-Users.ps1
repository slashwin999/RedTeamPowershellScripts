function Search-EventForUser {
	# Mr.Un1k0d3r - RingZer0 Team 2016
	# Search for a user through the events
	
	param(
	[Parameter(Mandatory=$True, ValueFromPipeline=$true)]
	[string]$TargetUser,
	[Parameter(Mandatory=$False)]
	[string]$ComputerName = (Get-Item env:COMPUTERNAME).Value,
	[Parameter(Mandatory=$False)]
	[switch]$FindDC = $False,
	[Parameter(Mandatory=$False)]
	[string]$Username,
	[Parameter(Mandatory=$False)]
	[string]$Password
	)
	
	BEGIN {
		if($Username -ne "") {
			$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
			$Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePassword
		}	
	}
	
	PROCESS {
		[System.Collections.ArrayList]$dcs = @() 
		if($FindDC) {
			Write-Output "[+] Enumrating all the DCs"
			ForEach($dc in [DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers) {
				Write-Output "[+] DC found: $($dc.Name)"
				$dcs.Add($dc.Name) | Out-Null
			}
		} else {
			$dcs.Add($ComputerName) | Out-Null
		}
		
		ForEach($dc in $dcs) {
			ForEach($item in $TargetUser) {
				Write-Output "[+] Parsing $($dc) Logs looking for $($item)"
				if($Creds) {
					Write-Output "[*] Remotely authenticated as $($Username)"
					$xmlFilter = "<QueryList><Query Id=""0"" Path=""Security""><Select Path=""Security"">*[System[(EventID=4624)] and EventData[Data[@Name=""TargetUserName""]=""$($item)""]]</Select></Query></QueryList>";
					$data = Get-WinEvent -FilterXml $xmlFilter -ComputerName $dc -ErrorAction SilentlyContinue -Credential $Creds | Select Message;
				} else {
					$xmlFilter = "<QueryList><Query Id=""0"" Path=""Security""><Select Path=""Security"">*[System[(EventID=4624)] and EventData[Data[@Name=""TargetUserName""]=""$($item)""]]</Select></Query></QueryList>";
					$data = Get-WinEvent -FilterXml $xmlFilter -ComputerName $dc -ErrorAction SilentlyContinue | Select Message;				
				}
				if($data) {
					ForEach($entry in $data) {
						Write-Output "`n[+] Event found" 
						ForEach($Line in $entry.Message.Split("`n")) {
							$Line | Select-String -Pattern "Account Name:"
							$Line | Select-String -Pattern "Account Domain:"
							$Line | Select-String -Pattern "Security ID:"
							$Line | Select-String -Pattern "Source Network Address:"
							$Line | Select-String -Pattern "Workstation Name:"
							$Line | Select-String -Pattern "Process Name:"
						}
					}
				} else {
					Write-Output "[-] No event found on $($dc)..."
				}
			}
		}
	}
	
	END {
		Write-Output "[+] Process completed..."
	}
}

function Search-FullNameToSamAccount {
	# Mr.Un1k0d3r - RingZer0 Team 2017
	# Get SamAccountName using displayname property search
	
	param(
		[Parameter(Mandatory=$True, ValueFromPipeline=$True)]
		[string]$Filter
	)

	BEGIN {
		$Users = @()
	}

	PROCESS {
		ForEach($User in $Filter) {
			Write-Output "[*] Searching for $($User)"
			$Query = "(&(objectCategory=User)(displayName=*$($User)*))"
			$Domain = New-Object System.DirectoryServices.DirectoryEntry

			$DirSearch = New-Object System.DirectoryServices.DirectorySearcher
			$DirSearch.SearchRoot = $Domain
			$DirSearch.PageSize = 100
			$DirSearch.Filter = $Query
			$DirSearch.SearchScope = "Subtree"

			ForEach($Item in $DirSearch.FindAll()) {
				$Data = $Item.Properties
				$Output = New-Object -TypeName PSObject -Property @{
					Name = $Data.givenname[0]
					SamAccount = $Data.samaccountname[0]
					Department = $Data.department[0]
					Description = $Data.description[0]
				}

				$Users += $Output
			}
			$Users | Format-Table -Wrap -AutoSize
			$Users = @()
		}
		
	}

	END {
		Write-Output "[*] Process completed..."
	}
}

function Ldap-GetProperty {
	param(
	[Parameter(Mandatory=$True, ValueFromPipeline=$True)]
	[string]$Filter,
	[Parameter(Mandatory=$True)]
	[string]$Property
	)
	
	BEGIN {
		$Output = @()
	}
	
	PROCESS {
		$Domain = New-Object System.DirectoryServices.DirectoryEntry

		$DirSearch = New-Object System.DirectoryServices.DirectorySearcher
		$DirSearch.SearchRoot = $Domain
		$DirSearch.PageSize = 100
		$DirSearch.Filter = $Filter
		$DirSearch.SearchScope = "Subtree"	
		
		ForEach($Item in $DirSearch.FindAll()) {
			$Data = $Item.Properties
			Try {
			$Element = New-Object -TypeName PSObject -Property @{
				$Property = $Data.$Property[0]
			}

			$Output += $Element		
			} Catch {
				Write-Output "[-] Property not found"
			}
		}
		return $Output
	}
	
}

function Search-UserPassword {
	
	param(
	[Parameter(Mandatory=$True, ValueFromPipeline=$True)]
	[string]$UserName
	)
	
	BEGIN {
	
	}
	
	PROCESS {
		ForEach($User in $UserName) {
			Write-Output "[*] $($User)"
			Ldap-GetProperty -Filter "(&(objectCategory=User)(samaccountname=*$($User)*))" -Property "userpassword" | Format-Table -Wrap -AutoSize
		}
	}
	
	END {
		Write-Output "[+] Process completed..."
	}
}
