class PiiKind(object):
    """!
    @brief The kind of Personal Identifiable Information (PII), as one of the enumeration values
    """
    PiiKind_None                = 0
    PiiKind_DistinguishedName   = 1
    PiiKind_GenericData         = 2
    PiiKind_IPv4Address         = 3
    PiiKind_IPv6Address         = 4
    PiiKind_MailSubject         = 5
    PiiKind_PhoneNumber         = 6
    PiiKind_QueryString         = 7
    PiiKind_SipAddress          = 8
    PiiKind_SmtpAddress         = 9
    PiiKind_Identity            = 10
    PiiKind_Uri                 = 11
    PiiKind_Fqdn                = 12
    PiiKind_IPv4AddressLegacy   = 13