# M365AdminAccessReviewer
Shows which M365 Objects have privileged access and what type: 
PIM, 
Direct, 
Currently elevated, 
Group Privileges and what Members are in those groups, 
Service Principal direct privileged role applied

Designed for organizations using PIM.

Limitation: If an admin is *BOTH* PIM eligible AND Directly Assigned, it will output "PIM Eligible + Currently Elevated".  I still need to fix this.

Vibe Coded.  Have fun, extend, but don't expect it to be pretty, elegant, or perfect. Save to an XLSX for filtering. Don't open any issues. I won't look at them.

Requires Microsoft Graph PowerShell.  Connect based on your environment type.  I copy and paste the code into a PowerShell prompt after connecting to Microsoft Graph PowerShell.

Contributors and Credits:
Microsoft Docs, 
ChatGPT Pro

If GPTs stole your code and didn't give you credit, sorry.

License: None. Use at your own risk and to your hearts desire for good and not evil.


