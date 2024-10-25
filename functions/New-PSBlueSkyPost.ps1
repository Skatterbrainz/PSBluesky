Function New-PSBlueSkyPost {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.String])]
    [Alias("skeet")]
    param(
        [parameter(Position = 0, Mandatory, HelpMessage = 'The text of the post')]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        [parameter(HelpMessage = 'The path to the image file.')]
        [ValidatePattern('.*\.(jpg|jpeg|png|gif)$')]
        [string]$ImagePath,
        [Parameter(HelpMessage = 'You should include ALT text for the image.')]
        [string]$ImageAlt,
        [Parameter(Mandatory, HelpMessage = 'A PSCredential with your BlueSky username and password')]
        [PSCredential]$Credential
    )

    Begin {
        Write-Verbose "[$((Get-Date).TimeOfDay) BEGIN  ] Starting $($MyInvocation.MyCommand)"
        Write-Verbose "[$((Get-Date).TimeOfDay) BEGIN  ] Using PowerShell version $($PSVersionTable.PSVersion)"
        $token = Get-PSBlueSkyAccessToken -Credential $Credential

    } #begin
    Process {
        If ($token) {
            $headers = @{
                Authorization  = "Bearer $token"
                'Content-Type' = 'application/json'
            }
            $apiUrl = "$($global:PDSHOST)/xrpc/com.atproto.repo.createRecord"
            Write-Verbose "[$((Get-Date).TimeOfDay) PROCESS] Posting message to $apiURL"

            $record = @{
                text      = $Message
                createdAt = (Get-Date -Format 'o')
            }

            if ($ImagePath) {
                if (-not $ImageAlt) {
                    Throw 'You must provide ALT text for the image.'
                }
                $image = Add-PSBlueSkyImage -ImagePath $ImagePath -ImageAlt $ImageAlt -Credential $Credential
                if ($image) {
                    $embed = @{
                        '$type' = 'app.bsky.embed.images'
                        images  = @(
                            @{
                                alt   = $ImageAlt
                                image = @{
                                    '$type'  = 'blob'
                                    ref      = @{'$link' = $image.link }
                                    mimeType = $image.mimeType
                                    size     = $image.size
                                }
                            }
                        )
                    }
                    $record.Add('embed', $embed)
                }
                else {
                    Throw "Failed to upload image $ImagePath. $($_.Exception.Message)"
                }
            }

            $body = @{
                repo       = $Credential.UserName
                collection = 'app.bsky.feed.post'
                record     = $record
            } | ConvertTo-Json -Depth 6

            if ($PSCmdlet.ShouldProcess($Message, 'Post to BlueSky')) {
                $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body
                $split = $response.uri -split '/' | where { $_ -match '\w' }
                $publicUri = 'https://bsky.app/profile/'
                $publicUri += '{0}/post/{1}' -f $split[1], $split[-1]
                $publicUri
            }
        }
        else {
            Write-Host 'Failed to authenticate.'
        }
    } #process
    End {
        Write-Verbose "[$((Get-Date).TimeOfDay) END    ] Ending $($MyInvocation.MyCommand)"
    } #end
}