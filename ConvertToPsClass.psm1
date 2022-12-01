function ConvertTo-PSClass {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSobject]$InputObject,
        [String]$RootClassName = "Root",
        [switch]$AsString
    )
    
    begin {
        
    }
    
    process {
        If ( $AsString ) {
            return ([entry]::new($InputObject,$RootClassName,$True)).ToString()
        }
        [entry]::new($InputObject,$RootClassName,$True)
    }
    
    end {
        
    }
}
