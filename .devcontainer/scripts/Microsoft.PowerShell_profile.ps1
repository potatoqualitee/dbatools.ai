# ignore the tls warnings
$null = Set-DbatoolsInsecureConnection

# set the default sql credential
$cred = New-Object PSCredential("sqladmin", (ConvertTo-SecureString "dbatools.IO" -AsPlainText -Force))
$PSDefaultParameterValues["*:SqlCredential"] = $cred