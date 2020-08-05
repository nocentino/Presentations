<#
	Author: 	Anthony E. Nocentino
	Email:		aen@centinosystems.com
	Description:	Various examples of redirecting output and errors using file descriptors and then the pipeline.
			Notice that the last example the pipeline stops execution after the Write-Error and never hits the Out-File
#>


Write-Output "This is stdout!" 1> ./output/std.out.fd
Write-Output "This is stdout!" | Out-File ./output/std.out.of

Write-Error "This is stderr!"  2> ./output/std.err.fd
Write-Error "This is stderr!"  | Out-File ./output/std.err.of

Get-Content ./output/std.out.fd
Get-Content ./output/std.out.of
Get-Content ./output/std.err.fd
Get-Content ./output/std.err.of
