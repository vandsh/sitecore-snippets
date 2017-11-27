$username = "<sdn username>"
$password = "<sdn password>"
$authUrl = "https://dev.sitecore.net/api/authorization"
$devUrl = "https://dev.sitecore.net"
$baseUrl = "http://sitecore.net"
$productlist = "http://dl.sitecore.net/updater/1.1/sim/products8.txt"
#$downloadPath = ($PSScriptRoot + "downloads") #make sure this path exists on your file system
$downloadPath = "C:\sitecore80\install\sitecore" #specific for SC-Docker example
$nl = [System.Environment]::NewLine

function GetSessionCookie([string]$url)
{
	$str
	[net.httpWebRequest] $httpWebRequest = [net.webRequest]::create($url)
	$cookieContainer = New-Object System.Net.CookieContainer
	$httpWebRequest.CookieContainer = $cookieContainer;
	[net.httpWebResponse] $response = $httpWebRequest.getResponse()
	
	$str = $cookieContainer.GetCookies($devUrl)["ASP.NET_SessionId"].ToString();
	
	$res.close()
	return $str
}

#build auth request
[net.httpWebRequest] $req = [net.webRequest]::create($authUrl)
$req.method = "POST"
$req.ContentType = "application/json;charset=UTF-8"
$cookieContainer = New-Object System.Net.CookieContainer
$req.CookieContainer = $cookieContainer
$authStr = "{" + ('"username":"{0}","password":"{1}"' -f $username, $password) + "}"
$buffer = [text.encoding]::ascii.getbytes($authStr)
$req.ContentLength = $buffer.length
$req.AllowAutoRedirect=$false

#submit auth request
$reqst = $req.getRequestStream()
$reqst.write($buffer, 0, $buffer.length)
$reqst.flush()
$reqst.close()
[net.httpWebResponse] $res = $req.getResponse()
$resst = $res.getResponseStream()
$sr = new-object IO.StreamReader($resst)
$result = $sr.ReadToEnd()
if($result -eq "true")
{
	$cookies = $cookieContainer.GetCookies($baseUrl);
	$item = $cookies["marketplace_login"]
	if ($item -eq $null)
	{
		Write-Host "The username or password or both are incorrect, or an unexpected error happened"
		$res.close()
	}
	else
	{
		$res.close()
		
		#get product list
		$prodListRequest = Invoke-WebRequest -Uri $productlist -UseBasicParsing
		$firstLine = ($prodListRequest -split $nl)[0] #split on newlines, and grab first line
		$firstLineArr = $firstLine.Split("|",[System.StringSplitOptions]::RemoveEmptyEntries) #Sitecore CMS|maj ver#|rev#|Update-#|url
		$SCDownloadUrl = $firstLineArr[4]
		#$SCFileName = ("{0} {1} {2} {3}.zip" -f $firstLineArr[0], $firstLineArr[1], $firstLineArr[2], $firstLineArr[3])
		$SCFileName = "sc8.zip" #normally above is used, using this for SC-Docker example
		New-Item -ItemType Directory -Force -Path $downloadPath #creates if does not exist...
		$SCFullFilePath = ("{0}\{1}" -f $downloadPath, $SCFileName)
		$sessCookie = GetSessionCookie($devUrl)
		$authCookie = ("{0};{1}" -f $item,$sessCookie)
		Write-Host ("Downloading Sitecore - " + $SCFileName) #debugging
		#download
		$web = new-object net.webclient
		$web.Headers.add("Cookie", $authCookie)
		$result = $web.DownloadFile($SCDownloadUrl,$SCFullFilePath)
		Write-Host ("PATH: " + $SCFullFilePath) -ForegroundColor green #debugging
	}
}


