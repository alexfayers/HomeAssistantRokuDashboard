function loadConfig()
    jsonAsString = ReadAsciiFile("pkg:/source/config.json")
    m.config = ParseJSON(jsonAsString)
end function

function createTransferObject()
	transferObject = createObject( "roUrlTransfer" )
	authHeader = "Bearer " + m.config.token
	transferObject.AddHeader("Authorization", authHeader)
	transferObject.AddHeader("Content-Type", "application/json")
	return transferObject
end function

function init()
	loadConfig()
	m.port = createObject("roMessagePort")
	m.top.observeField("request", m.port)
	m.top.functionName = "go"
	m.top.control = "RUN"
    m.urlTransferPool = []
    m.ret = true
end function

function go() as Void
	m.jobsById = {}
	while true
		msg = wait(0, m.port)
		mt = type(msg)
		if mt="roSGNodeEvent"
			if msg.getField()="request"
				m.ret = addRequest(msg.getData())
			else
				print "UriFetcher: unrecognized field '"; msg.getField(); "'"
			end if
		else if mt="roUrlEvent"
			processResponse(msg)
		else
			print "UriFetcher: unrecognized event type '"; mt; "'"
		end if
        if m.ret = false
            ? "too many requests"
        end if
		print "RETURN VALUE ----- "; m.ret
	end while
end function

function addRequest(request as Object) as Boolean
	if type(request) = "roAssociativeArray"
        context = request.context
        if type(context)="roSGNode"
            parameters = context.parameters
            if type(parameters)="roAssociativeArray"
		        uri = parameters.uri
		        if type(uri) = "roString"
					m.urlTransferPool.Push(createTransferObject())

			        m.urlTransferPool.Peek().setUrl(uri)
			        m.urlTransferPool.Peek().setPort(m.port)
			        ' should transfer more stuff from parameters to urlXfer
			        idKey = stri(m.urlTransferPool.Peek().getIdentity()).trim()

					if parameters.payload <> invalid ' post request
						ok = m.urlTransferPool.Peek().AsyncPostFromString(parameters.payload)
					else
                    	ok = m.urlTransferPool.Peek().AsyncGetToString()
					end if

					if not ok
						print "Failed due to: " + m.urlTransferPool.Peek().GetFailureReason()
						return false
                    endif
			        if ok
                        m.jobsById[idKey] = {context: context, xfer: m.urlTransferPool}
												? "jobsbyID: "; m.jobsbyID.count()
				        print "UriFetcher: initiating transfer '"; idkey; "' for URI '"; uri; "'"; " succeeded: "; ok
										else
                        print "UriFetcher: invalid uri: "; uri
                    endif
		        end if
            end if
	    end if
	end if
    return true
end function

function processResponse(msg as Object)
	idKey = stri(msg.GetSourceIdentity()).trim()

	job = m.jobsById[idKey]

    print "Number of jobs in queue: "; m.jobsById.count()
    print "Number of urlXfer objects in pool: " m.urlTransferPool.count()

    if job<>invalid
        m.urlTransferPool.Shift()

		m.ret = true
        context = job.context
        parameters = context.parameters
        uri = parameters.uri
		print "UriFetcher: response for transfer '"; idkey; "' for URI '"; uri; "'"
		result = {code: msg.getResponseCode(), content: msg.getString()}
		' could handle various error codes, retry, etc.
		m.jobsById.delete(idKey)
        job.context.response = result
	else
		print "UriFetcher: event for unknown job "; idkey
	end if
end function
