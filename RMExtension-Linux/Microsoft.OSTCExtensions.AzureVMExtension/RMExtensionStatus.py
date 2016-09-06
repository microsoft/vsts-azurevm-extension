#!/usr/bin/python

RMExtensionStatus = {
		'Success' : {
				'Code' : 1,
				'Message' : 'RM extension was applied successfully'
				},
		'Initializing' : { 
				'Code' : 2,
                                'Message' : 'Initializing RM extension'
                                },
		'Initialized' : {
				'Code' : 3,
                                'Message' : 'Done Initializing RM extension'
                                },
		'Enabled' : {
				'Code' : 3,
                                'Message' : 'RM extension has been enabled'
                                },
		'DownloadedVSTSAgent' : {
				'Code' : 4,
                                'Message' : 'Downloaded VSTS agent package'
                                },
		'RebootingDSC' : {
				'Code' : 5,
                                'Message' : 'Rebooting VM to apply DSC comfigutation'
                                },
		'GenericWarning' : 100,
		'GenericError' : 1000,
		'InstallError' : 1001,
		'ArgumrntError' : 1100
	}
