
function Get-DecryptedString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [securestring]$SecureString
    )
    try {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $PlainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $PlainToken
    } catch {
        Write-Error -Exception $_.Exception
    } finally {
        $bstr = $PlainToken = $null
    }
}
