function Send-EmailMessage {
[CmdLetBinding()]
    Param($Message,$EmailAddress,$Subject)

    $messageParameters = @{
        Subject = $Subject
        Body = "$Message"
        To = $EmailAddress
        From = "do-not-reply@usc.edu.au"
        SmtpServer = "mail.usc.edu.au"
    }
    Send-MailMessage @messageParameters
}
