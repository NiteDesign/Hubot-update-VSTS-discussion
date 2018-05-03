################################################################
# TFS story links
#
#	Description:
#		Script that will return a link to TFS when someone mentions a story or bug #
#		it will then inject the message into the corresponding VSTS discussion
#		providing a Slack URL to the Slack message
#
# Commands:
#
# Dependencies:
#
# Author:
#		Ryan Lawyer
#
################################################################
################################################################
# TFS story links
#
#	Description:
#		Script that will return a link to TFS when someone mentions a story #
#
# Commands:
#
# Dependencies:
#
# Author:
#		Ryan Lawyer
#
################################################################

https = require 'https'
# NOTE!
# Token must be Base64
# Obtain token from TFS, in Powershell run with this
# $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))
tfsHostName = 'yourVSTShostname.visualstudio.com'
tfsToken = 'yourVSTSToken'
slackToken = 'yourSlackHubotToken'

getPR = (tfsObjectId, slack) ->
	projectOptions =
		hostname: tfsHostName,
		port: '443',
		path: '/DefaultCollection/_apis/git/pullRequests/' + tfsObjectId + '?api-version=3.0'
		method: 'GET',
		headers:
			'Authorization': 'Basic ' + tfsToken

	request = https.get(projectOptions, (res) ->
		body = ''
		res.on 'data', (chunk) ->
			body += chunk.toString()
		res.on 'end', () ->
			jsonData = JSON.parse(body)
			slack.send "Here's some info for PR <" + jsonData.repository.remoteUrl + "/pullrequest/" + slack.match[1] + "#_a=overview|#" + slack.match[1] + "> within the *" + jsonData.repository['name'] + "* repository.\n*Title:* " + jsonData.title + "\n*Created By:* " + jsonData.createdBy['displayName'] + "\n*Status:* " + jsonData.status + "\n*Source:* " + jsonData.sourceRefName + "\n*Target:* " + jsonData.targetRefName
		)

getItem = (tfsObjectId, slack) ->
	projectOptions =
		hostname: tfsHostName,
		port: '443',
		path: '/DefaultCollection/_apis/wit/workitems?ids=' + tfsObjectId + '&api-version=1.0'
		method: 'GET',
		headers:
			'Authorization': 'Basic ' + tfsToken

	request = https.get(projectOptions, (res) ->
		body = ''
		res.on 'data', (chunk) ->
			body += chunk.toString()
		res.on 'end', () ->
			jsonData = JSON.parse(body)
			slack.send "Here's some info for that " + slack.match[1] + " <https://" + tfsHostName + "/" + jsonData.value[0].fields['System.TeamProject'] + "/_workitems?id=" + slack.match[2] + "&_a=edit|#" + slack.match[2] + ">:\n*Title:* " + jsonData.value[0].fields['System.Title'] + "\n*Created By:* " + jsonData.value[0].fields['System.CreatedBy'] + "\n*State:* " + jsonData.value[0].fields['System.State'] + "\n*Assigned to:* " + jsonData.value[0].fields['System.AssignedTo']
		)

getSlackPermaLink = (tfsObjectId, slack) ->
	options =
		hostname: 'slack.com',
		port: '443',
		path: '/api/chat.getPermalink?channel=' + slack.message.room + '&message_ts=' + slack.message.id + '&token=' + slackToken
		method: 'GET',
		headers:
			'Content-Type': 'application/x-www-form-urlencoded'

	request = https.get(options, (res) ->
		body = ''
		res.on 'data', (chunk) ->
			body += chunk.toString()
		res.on 'end', () ->
			jsonData = JSON.parse(body)
			updateVSTSDiscussion(tfsObjectId, slack, jsonData.permalink);
		)

updateVSTSDiscussion = (tfsObjectId, slack, permaLink) ->
	post_data = "[  \r\n  {\r\n    \"op\": \"add\",\r\n    \"path\": \"/fields/System.History\",\r\n    \"value\": \"Mentioned on <a href=" + permaLink + ">Slack</a> by: " + slack.message.user.real_name + "<br />" + slack.message.text + "\"\r\n  }\r\n]"
	options =
		hostname: tfsHostName,
		port: '443',
		path: '/DefaultCollection/_apis/wit/workitems/' + tfsObjectId + '?api-version=4.1'
		method: 'PATCH',
		headers:
			'Authorization': 'Basic ' + tfsToken,
			'Content-Type': 'application/json-patch+json',
			'Content-Length': Buffer.byteLength(post_data)

	request = https.request(options, (res) ->
		body = ''
		res.on 'data', (chunk) ->
			body += chunk.toString()
		res.on 'end', () ->
			jsonData = JSON.parse(body)
			#console.log body
	)

	request.write(post_data);
	request.end();

################################################################
module.exports = (robot) ->

	robot.hear /pr \#?(\d{3,5})/i, (slack) ->
		getPR(slack.match[1], slack)

	robot.hear /(story|bug) \#?(\d{5,6})/i, (slack) ->
		getItem(slack.match[2], slack)
		getSlackPermaLink(slack.match[2], slack)
