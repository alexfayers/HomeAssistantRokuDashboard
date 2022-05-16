function init()
    loadConfig()

    m.statusList = m.top.FindNode("statusListContent")
    m.serviceList = m.top.FindNode("serviceListContent")

    m.uriFetcher = createObject("roSGNode", "UriFetcher")

    m.buttonActions = []
    populateServiceButtons()

    getAllStates() ' initial states

    timer = m.top.findNode("refreshTimer")
    timer.duration = m.config.refresh_rate
    timer.control = "start"
  
    timer.ObserveField("fire","getAllStates")  ' refresh
    m.top.setFocus(true)
end function

function loadConfig()
    jsonAsString = ReadAsciiFile("pkg:/source/config.json")
    m.config = ParseJSON(jsonAsString)
end function

function makeRequest(parameters as Object, callback as String)
    print parameters
    context = createObject("RoSGNode","Node")
    if type(parameters)="roAssociativeArray"
        context.addFields({parameters: parameters, response: {}})
        context.observeField("response", callback) ' response callback is request-specific
        m.uriFetcher.request = {context: context}
    end if
end function

function createSectionNode(section as String)
    newSection = createObject("RoSGNode","LayoutGroup")
    newSection.id = section

    header = newSection.createChild("Label")
    header.text = section
    header.vertAlign = "bottom"
    header.height = 50
    header.font = "font:MediumBoldSystemFont" 

    return newSection
end function

function getAllStates()
    m.statusList.removeChildren(m.statusList.getChildren(-1, 0))

    for each section in m.config.entities
        newSection = createSectionNode(section)        
        m.statusList.appendChild(newSection)

        for each entity in m.config.entities[section]
            getState(section, entity)
        end for
    end for
end function

function getState(sectionName as String, entityId as String)
    requesturl = m.config.host + "/api/states/" + entityId

    makeRequest({sectionName: sectionName, uri: requesturl}, "uriResult")
end function

function createServiceButton(serviceName as String, endpoint as String, payload as String)
    newButton = createObject("RoSGNode","Button")
    newButton.text = serviceName

    m.buttonActions.Unshift({
        endpoint: endpoint,
        payload: payload    
    })

    return newButton
end function

function serviceButtonSelected()
    buttonId = m.serviceList.buttonSelected
    callService(m.buttonActions[buttonId].endpoint, m.buttonActions[buttonId].payload)
    print buttonId
endfunction

function populateServiceButtons()
    for each section in m.config.services
        newSection = createSectionNode(section)        
        m.serviceList.appendChild(newSection)
        sectionIndex = m.serviceList.getChildCount()

        for each service in m.config.services[section]
            endpoint = m.config.services[section][service]["endpoint"]
            payload = FormatJson(m.config.services[section][service]["payload"])

            m.serviceList.insertChild(createServiceButton(service, endpoint, payload), sectionIndex)
        end for
    end for

    m.serviceList.ObserveField("buttonSelected", "serviceButtonSelected")
end function

function callService(serviceEndpoint as String, payload as String)
    requesturl = m.config.host + "/api/services/" + serviceEndpoint

    makeRequest({ uri: requesturl, payload: payload}, "callServiceCallback")
end function

function callServiceCallback(msg as Object)
    print msg.getData()
end function

function uriResult(msg as Object)
	mt = type(msg)
	if mt="roSGNodeEvent"
		print "UriFetcherTestScene: results obtained"
        context = msg.getRoSGNode()
        response = msg.getData()
        rt = type(response)
        if rt ="roAssociativeArray"
            parameters = context.parameters
		    print "  uri: "; parameters.uri
		    print "  response: "; response

            json = ParseJSON(response.content)

            name = json.attributes.friendly_name
            state = json.state
            
            newSection = createObject("RoSGNode","LayoutGroup")
            newSection.layoutDirection = "horiz"
            newSection.itemSpacings = [100, 0]

            nameNode = newSection.createChild("ScrollingLabel")
            nameNode.text = name
            nameNode.maxWidth = 300

            stateNode = newSection.createChild("ScrollingLabel")
            stateNode.text = state
            stateNode.maxWidth = 200

            m.top.FindNode(context.parameters.sectionName).appendChild(newSection)
        else
            print "UriFetcherTestScene: unknown response type '"; rt; "'"
        end if
	else
		print "UriFetcherTestScene: unknown msg type '"; mt; "'"
	end if

end function