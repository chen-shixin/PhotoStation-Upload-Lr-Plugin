--[[----------------------------------------------------------------------------

PSPublishSupport.lua
Publish support for Lightroom PhotoStation Upload
Copyright(c) 2015, Martin Messmer

This file is part of PhotoStation Upload - Lightroom plugin.

PhotoStation Upload is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PhotoStation Upload is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PhotoStation Upload.  If not, see <http://www.gnu.org/licenses/>.

PhotoStation Upload uses the following free software to do its job:
	- convert.exe,			see: http://www.imagemagick.org/
	- ffmpeg.exe, 			see: https://www.ffmpeg.org/
	- qt-faststart.exe, 	see: http://multimedia.cx/eggs/improving-qt-faststart/

This code is derived from the Lr SDK FTP Export and Flickr sample code. Copyright: see below
--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007-2010 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

	-- Lightroom SDK
local LrDate = 		import 'LrDate'
local LrDialogs = 	import 'LrDialogs'
local LrHttp = 		import 'LrHttp'
local LrPathUtils = import 'LrPathUtils'
local LrView = 		import 'LrView'

require "PSUtilities"
require 'PSUploadTask'
require 'PSFileStationAPI'
require 'PSUploadExportDialogSections'

--===========================================================================--

local publishServiceProvider = {}

--------------------------------------------------------------------------------
--- (string) Plug-in defined value is the filename of the icon to be displayed
 -- for this publish service provider, in the Publish Services panel, the Publish 
 -- Manager dialog, and in the header shown when a published collection is selected.
 -- The icon must be in PNG format and no more than 24 pixels wide or 19 pixels tall.

publishServiceProvider.small_icon = 'PhotoStation.png'

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the behavior of the
 -- Description entry in the Publish Manager dialog. If the user does not provide
 -- an explicit name choice, Lightroom can provide one based on another entry
 -- in the publishSettings property table. This entry contains the name of the
 -- property that should be used in this case.
	
-- publishServiceProvider.publish_fallbackNameBinding = 'fullname'

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published collection, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Collection." </p>
	
publishServiceProvider.titleForPublishedCollection = LOC "$$$/PSPublish/TitleForPublishedCollection=Published Collection"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection to match the terminology used on the service you are targeting.
 -- <p>Unlike <code>titleForPublishedCollection</code>, this string is typically
 -- used by itself. In English, these strings nay be the same, but in
 -- other languages (notably German), you may have to use a different form
 -- of the name to be gramatically correct. If you are localizing your plug-in,
 -- use a separate translation key to make this possible.</p>
 -- <p>If not provided, Lightroom uses the value of
 -- <code>titleForPublishedCollection</code> instead.</p>

publishServiceProvider.titleForPublishedCollection_standalone = LOC "$$$/PSPublish/TitleForPublishedCollection/Standalone=Published Collection"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection set to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published collection set, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Collection Set." </p>
	
-- publishServiceProvider.titleForPublishedCollectionSet = "(something)" -- not used for Flickr plug-in

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection to match the terminology used on the service you are targeting.
 -- <p>Unlike <code>titleForPublishedCollectionSet</code>, this string is typically
 -- used by itself. In English, these strings may be the same, but in
 -- other languages (notably German), you may have to use a different form
 -- of the name to be gramatically correct. If you are localizing your plug-in,
 -- use a separate translation key to make this possible.</p>
 -- <p>If not provided, Lightroom uses the value of
 -- <code>titleForPublishedCollectionSet</code> instead.</p>

--publishServiceProvider.titleForPublishedCollectionSet_standalone = "(something)" -- not used for Flickr plug-in

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- smart collection to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published smart collection, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Smart Collection." </p>

publishServiceProvider.titleForPublishedSmartCollection = LOC "$$$/PSPublish/TitleForPublishedSmartCollection=Published Smart Collection"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- smart collection to match the terminology used on the service you are targeting.
 -- <p>Unlike <code>titleForPublishedSmartCollection</code>, this string is typically
 -- used by itself. In English, these strings may be the same, but in
 -- other languages (notably German), you may have to use a different form
 -- of the name to be gramatically correct. If you are localizing your plug-in,
 -- use a separate translation key to make this possible.</p>
 -- <p>If not provided, Lightroom uses the value of
 -- <code>titleForPublishedSmartCollectionSet</code> instead.</p>

publishServiceProvider.titleForPublishedSmartCollection_standalone = LOC "$$$/PSPublish/TitleForPublishedSmartCollection/Standalone=Published Smart Collection"

--------------------------------------------------------------------------------
-- This (optional) plug-in defined callback function is called when publishing has been initiated, 
-- and should simply return true or false to indicate whether any deletion of photos from the service 
-- should take place before any publishing of new images and updating of previously published images.
function publishServiceProvider.deleteFirstOnPublish()
	return true
end

--------------------------------------------------------------------------------
--- (optional) If you provide this plug-in defined callback function, Lightroom calls it to
 -- retrieve the default collection behavior for this publish service, then use that information to create
 -- a built-in <i>default collection</i> for this service (if one does not yet exist). 
 
function publishServiceProvider.getCollectionBehaviorInfo( publishSettings )

	return {
		defaultCollectionName = LOC "$$$/PSPublish/DefaultCollectionName/Collection=Collection",
		defaultCollectionCanBeDeleted = false,
		canAddCollection = true,
		maxCollectionSetDepth = 0,
			-- Collection sets are not supported through the PhotoStation Upload plug-in.
	}
	
end

--------------------------------------------------------------------------------
--- When set to the string "disable", the "Go to Published Collection" context-menu item
 -- is disabled (dimmed) for this publish service.

publishServiceProvider.titleForGoToPublishedCollection = LOC "$$$/PSPublish/TitleForGoToPublishedCollection=Show in PhotoStation"

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user chooses
 -- the "Go to Published Collection" context-menu item.
function publishServiceProvider.goToPublishedCollection( publishSettings, info )
	local albumUrl 
	
	-- TODO: use the correct album url, not the PhotoStation base url
	
	if publishSettings.usePersonalPS then
		albumUrl = publishSettings.serverUrl .. "/~" .. publishSettings.personalPSOwner .. "/photo"
	else
		albumUrl = publishSettings.serverUrl .. "/photo"
	end
	LrHttp.openUrlInBrowser(albumUrl)
end

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value overrides the label for the 
 -- "Go to Published Photo" context-menu item, allowing you to use something more appropriate to
 -- your service. Set to the special value "disable" to disable (dim) the menu item for this service. 

publishServiceProvider.titleForGoToPublishedPhoto = LOC "$$$/PSPublish/TitleForGoToPublishedCollection=Show in PhotoStation"

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user chooses the
 -- "Go to Published Photo" context-menu item.
function publishServiceProvider.goToPublishedPhoto( publishSettings, info )
	local albumUrl 
	
	-- TODO: use the correct photo url, not the PhotoStation base url
	
	if publishSettings.usePersonalPS then
		albumUrl = publishSettings.serverUrl .. "/~" .. personalPSOwner .. "/photo"
	else
		albumUrl = publishSettings.serverUrl .. "/photo"
	end
	LrHttp.openUrlInBrowser(albumUrl)
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user creates
 -- a new publish service via the Publish Manager dialog. It allows your plug-in
 -- to perform additional initialization.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.didCreateNewPublishService( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user creates
 -- a new publish service via the Publish Manager dialog. It allows your plug-in
 -- to perform additional initialization.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.didUpdatePublishService( publishSettings, info )
end

]]--

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete the publish service from Lightroom.
 -- It provides an opportunity for you to customize the confirmation dialog.
 -- @return (string) 'cancel', 'delete', or nil (to allow Lightroom's default
 -- dialog to be shown instead)
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.shouldDeletePublishService( publishSettings, info )
end

]]--

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has confirmed the deletion of the publish service from Lightroom.
 -- It provides a final opportunity for	you to remove private data
 -- immediately before the publish service is removed from the Lightroom catalog.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.willDeletePublishService( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete one or more published collections defined by your
 -- plug-in from Lightroom. It provides an opportunity for you to customize the
 -- confirmation dialog.
 -- @return (string) "ignore", "cancel", "delete", or nil
 -- (If you return nil, Lightroom's default dialog will be displayed.)
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.shouldDeletePublishedCollection( publishSettings, info )
end

]]--

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has attempted to delete one or more photos from the Lightroom catalog that are
 -- published through your service. It provides an opportunity for you to customize
 -- the confirmation dialog.
function publishServiceProvider.shouldDeletePhotosFromServiceOnDeleteFromCatalog( publishSettings, nPhotos )
	if nPhotos < 10 then
		return "delete"
	else
		-- ask the user for confirmation
		return nil
	end
end


--------------------------------------------------------------------------------
--- This plug-in defined callback function is called when one or more photos
 -- have been removed from a published collection and need to be removed from
 -- the service. If the service you are supporting allows photos to be deleted
 -- via its API, you should do that from this function.

function publishServiceProvider.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds, deletedCallback )
	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	-- open session: initialize environment, get missing params and login
	if not openSession(publishSettings, 'Delete') then
		writeLogfile(1, "deletePhotosFromPublishedCollection: cannot open session!\n" )
		return
	end

	for i, photoId in ipairs( arrayOfPhotoIds ) do
		writeLogfile(2, 'deletePhotosFromPublishedCollection:  "' .. photoId .. '"\n')
		if PSFileStationAPI.deletePic (photoId) then
			deletedCallback( photoId )
		else
			writeLogfile(1, 'deletePhotosFromPublishedCollection:  "' .. photoId .. '" failed!\n')
		end
	end

	closeSession(publishSettings, 'Delete');

end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called whenever a new
 -- publish service is created and whenever the settings for a publish service
 -- are changed. It allows the plug-in to specify which metadata should be
 -- considered when Lightroom determines whether an existing photo should be
 -- moved to the "Modified Photos to Re-Publish" status.
function publishServiceProvider.metadataThatTriggersRepublish( publishSettings )

	return {

		default = false,
		title = true,
		caption = true,
		keywords = true,
		gps = true,
		gpsAltitude = true,
		dateCreated = true,
--		path = true,		-- check for local file movements: doesn't work

		-- also (not used by Flickr sample plug-in):
			-- customMetadata = true,
			-- com.whoever.plugin_name.* = true,
			-- com.whoever.plugin_name.field_name = true,

	}

end

-- updatCollectionStatus: do some sanity checks on Published Collection dialog settings
local function updateCollectionStatus( collectionSettings )
	
	local message = nil
	
	repeat
		-- Use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		
		if collectionSettings.copyTree and not validateDirectory(nil, collectionSettings.srcRoot) then
			message = LOC "$$$/PSUpload/CollectionDialog/Messages/EnterSubPath=Enter a source path"
			break
		end
				
		if not collectionSettings.copyTree and collectionSettings.publishMode == 'CheckMoved' then
			message = LOC ("$$$/PSUpload/CollectionDialog/CheckMovedNotNeeded=CheckMoved not supported if not mirror tree copy.\n")
			break
		end
	until true
	
	if message then
		collectionSettings.hasError = true
		collectionSettings.message = message
		collectionSettings.LR_canSaveCollection = false
	else
		collectionSettings.hasError = false
		collectionSettings.message = nil
		collectionSettings.LR_canSaveCollection = true
	end
	
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- creates a new published collection or edits an existing one. It can add
 -- additional controls to the dialog box for editing this collection. 
function publishServiceProvider.viewForCollectionSettings( f, publishSettings, info )
	local bind = LrView.bind
	local share = LrView.share

	local collectionSettings = assert( info.collectionSettings )

	-- observe settings to enablle/disable "Store" button
	if collectionSettings.hasError == nil then
		collectionSettings.hasError = false
	end

	collectionSettings:addObserver( 'srcRoot', updateCollectionStatus )
	collectionSettings:addObserver( 'copyTree', updateCollectionStatus )
	collectionSettings:addObserver( 'publishMode', updateCollectionStatus )
	updateCollectionStatus( collectionSettings )
		
	if collectionSettings.storeDstRoot == nil then
		collectionSettings.storeDstRoot = true
	end

	if collectionSettings.dstRoot == nil then
		collectionSettings.dstRoot = ''
	end

	if collectionSettings.createDstRoot == nil then
		collectionSettings.createDstRoot = false
	end

	if collectionSettings.copyTree == nil then
		collectionSettings.copyTree = false
	end

	if collectionSettings.srcRoot == nil then
		collectionSettings.srcRoot = ''
	end

	if collectionSettings.publishMode == nil then
		collectionSettings.publishMode = 'Publish'
	end

	return f:group_box {
		title = "PhotoStation Upload Settings",  -- this should be localized via LOC
		size = 'small',
		fill_horizontal = 1,
		bind_to_object = assert( collectionSettings ),
		
		f:column {
			fill_horizontal = 1,
			spacing = f:label_spacing(),

--[[
			f:checkbox {
				title = "Enable Rating",  -- this should be localized via LOC
				value = bind 'enableRating',
			},

			f:checkbox {
				title = "Enable Comments",  -- this should be localized via LOC
				value = bind 'enableComments',
			},
]]

			f:row {
				f:static_text {
					title = LOC "$$$/PSUpload/ExportDialog/StoreDstRoot=Enter Target Album:",
					alignment = 'right',
					width = share 'labelWidth'
				},

				f:edit_field {
					tooltip = LOC "$$$/PSUpload/ExportDialog/DstRootTT=Enter the target directory below the diskstation share '/photo' or '/home/photo'\n(may be different from the Album name shown in PhotoStation)",
					value = bind 'dstRoot',
					truncation = 'middle',
					immediate = true,
					fill_horizontal = 1,
				},

				f:checkbox {
					title = LOC "$$$/PSUpload/ExportDialog/createDstRoot=Create Album, if needed",
					alignment = 'left',
					width = share 'labelWidth',
					value = bind 'createDstRoot',
					fill_horizontal = 1,
				},
			},
			
			f:row {
				f:radio_button {
					title = LOC "$$$/PSUpload/ExportDialog/FlatCp=Flat copy to Target Album",
					tooltip = LOC "$$$/PSUpload/ExportDialog/FlatCpTT=All photos/videos will be copied to the Target Album",
					alignment = 'right',
					value = bind 'copyTree',
					checked_value = false,
					width = share 'labelWidth',
				},

				f:radio_button {
					title = LOC "$$$/PSUpload/ExportDialog/CopyTree=Mirror tree relative to Local Path:",
					tooltip = LOC "$$$/PSUpload/ExportDialog/CopyTreeTT=All photos/videos will be copied to a mirrored directory below the Target Album",
					alignment = 'left',
					value = bind 'copyTree',
					checked_value = true,
				},

				f:edit_field {
					value = bind 'srcRoot',
					tooltip = LOC "$$$/PSUpload/ExportDialog/CopyTreeTT=Enter the local path that is the root of the directory tree you want to mirror below the Target Album.",
					enabled = bind 'copyTree',
					visible = bind 'copyTree',
					validate = validateDirectory,
					truncation = 'middle',
					immediate = true,
					fill_horizontal = 1,
				},
			},

			f:row {
				alignment = 'left',
--				fill_horizontal = 1,

				f:static_text {
					title = LOC "$$$/PSUpload/CollectionSettings/PublishMode=Publish Mode:",
					alignment = 'right',
				},
				f:popup_menu {
					tooltip = LOC "$$$/PSUpload/CollectionSettings/PublishModeTT=How to publish",
					value = bind 'publishMode',
					alignment = 'left',
					fill_horizontal = 1,
					items = {
						{ title	= 'Ask me later',																value 	= 'Ask' },
						{ title	= 'Normal',																		value 	= 'Publish' },
						{ title	= 'CheckExisting: Set Unpublished to Published if existing in PhotoStation.',	value 	= 'CheckExisting' },
						{ title	= 'CheckMoved: Set Published to Unpublished if moved locally.',					value 	= 'CheckMoved' },
					},
				},
			},

			f:separator { fill_horizontal = 1 },

			f:row {
				alignment = 'left',

				f:static_text {
					title = bind 'message',
					fill_horizontal = 1,
					visible = bind 'hasError'
				},
			},
		},
	}

end

function publishServiceProvider.updateCollectionSettings(publishSettings, info)
	local collectionSettings = assert( info.collectionSettings )

end 

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- creates a new published collection set or edits an existing one. It can add
 -- additional controls to the dialog box for editing this collection set. 
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.viewForCollectionSetSettings( f, publishSettings, info )
	-- See viewForCollectionSettings example above.
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- closes the dialog for creating a new published collection or editing an existing
 -- one. 
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.endDialogForCollectionSettings( publishSettings, info )
	-- not used for PhotoStation Upload plug-in
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- closes the dialog for creating a new published collection set or editing an existing
 -- one. 
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.endDialogForCollectionSetSettings( publishSettings, info )
	-- not used for PhotoStation Upload plug-in
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has changed the per-collection settings defined via the <code>viewForCollectionSettings</code>
 -- callback. It is your opportunity to update settings on your web service to
 -- match the new settings.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.updateCollectionSettings( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user
 -- has changed the per-collection set settings defined via the <code>viewForCollectionSetSettings</code>
 -- callback. It is your opportunity to update settings on your web service to
 -- match the new settings.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.updateCollectionSetSettings( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when new or updated
 -- photos are about to be published to the service. It allows you to specify whether
 -- the user-specified sort order should be followed as-is or reversed.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.shouldReverseSequenceForPublishedCollection( publishSettings, collectionInfo )

	return false

end
]]

--------------------------------------------------------------------------------
--- (Boolean) If this plug-in defined property is set to true, Lightroom will
 -- enable collections from this service to be sorted manually and will call
 -- the <a href="#publishServiceProvider.imposeSortOrderOnPublishedCollection"><code>imposeSortOrderOnPublishedCollection</code></a>
 -- callback to cause photos to be sorted on the service after each Publish
publishServiceProvider.supportsCustomSortOrder = false
	
--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called after each time
 -- that photos are published via this service assuming the published collection
 -- is set to "User Order." Your plug-in should ensure that the photos are displayed
 -- in the designated sequence on the service.
--[[
function publishServiceProvider.imposeSortOrderOnPublishedCollection( publishSettings, info, remoteIdSequence )
	return
	local photosetId = info.remoteCollectionId

	if photosetId then

		-- Get existing list of photos from the photoset. We want to be sure that we don't
		-- remove photos that were posted to this photoset by some other means by doing
		-- this call, so we look for photos that were missed and reinsert them at the end.

		local existingPhotoSequence = FlickrAPI.listPhotosFromPhotoset( publishSettings, { photosetId = photosetId } )

		-- Make a copy of the remote sequence from LR and then tack on any photos we didn't see earlier.
		
		local combinedRemoteSequence = {}
		local remoteIdsInSequence = {}
		
		for i, id in ipairs( remoteIdSequence ) do
			combinedRemoteSequence[ i ] = id
			remoteIdsInSequence[ id ] = true
		end
		
		for _, id in ipairs( existingPhotoSequence ) do
			if not remoteIdsInSequence[ id ] then
				combinedRemoteSequence[ #combinedRemoteSequence + 1 ] = id
			end
		end
		
		-- There may be no photos left in the set, so check for that before trying
		-- to set the sequence.
		if existingPhotoSequence and existingPhotoSequence.primary then
			FlickrAPI.setPhotosetSequence( publishSettings, {
									photosetId = photosetId,
									primary = existingPhotoSequence.primary,
									photoIds = combinedRemoteSequence } )
		end
								
	end
end
]]

-------------------------------------------------------------------------------
--- This plug-in defined callback function is called when the user attempts to change the name
 -- of a collection, to validate that the new name is acceptable for this service.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.validatePublishedCollectionName( proposedName )
	return true
end

--]]

-------------------------------------------------------------------------------
--- (Boolean) This plug-in defined value, when true, disables (dims) the Rename Published
 -- Collection command in the context menu of the Publish Services panel 
 -- for all published collections created by this service. 
publishServiceProvider.disableRenamePublishedCollection = false

-------------------------------------------------------------------------------
--- (Boolean) This plug-in defined value, when true, disables (dims) the Rename Published
 -- Collection Set command in the context menu of the Publish Services panel
 -- for all published collection sets created by this service. 

publishServiceProvider.disableRenamePublishedCollectionSet = false

-------------------------------------------------------------------------------
--- This plug-in callback function is called when the user has renamed a
 -- published collection via the Publish Services panel user interface. This is
 -- your plug-in's opportunity to make the corresponding change on the service.

 function publishServiceProvider.renamePublishedCollection( publishSettings, info )
	return
end

-------------------------------------------------------------------------------
--- This plug-in callback function is called when the user has reparented a
 -- published collection via the Publish Services panel user interface. This is
 -- your plug-in's opportunity to make the corresponding change on the service.

--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.reparentPublishedCollection( publishSettings, info )
end

]]--

-------------------------------------------------------------------------------
--- This plug-in callback function is called when the user has deleted a
 -- published collection via the Publish Services panel user interface. This is
 -- your plug-in's opportunity to make the corresponding change on the service.
function publishServiceProvider.deletePublishedCollection( publishSettings, info )
	-- make sure logfile is opened
	openLogfile(publishSettings.logLevel)

	-- open session: initialize environment, get missing params and login
	if not openSession(publishSettings, 'Delete') then
		writeLogfile(1, "deletePhotosFromPublishedCollection: cannot open session!\n" )
		return
	end

	writeLogfile(3, "deletePublishedCollection: starting\n ")
	local message
	local startTime = LrDate.currentTime()
	local timeUsed
	local timePerPic	
	local publishedPhotos = info.publishedCollection:getPublishedPhotos() 
	local nPhotos = #publishedPhotos
	local nProcessed = 0 
	
	writeLogfile(2, string.format("deletePublishedCollection: deleting %d published photos from collection %s\n ", nPhotos, info.name ))

	-- Set progress title.
	import 'LrFunctionContext'.callWithContext( 'publishServiceProvider.deletePublishedCollection', function( context )
	
		local progressScope = LrDialogs.showModalProgressDialog {
							title = LOC( "$$$/PSPublish/DeletingCollectionAndContents=Deleting collection ^[^1^]", info.name ),
							functionContext = context }
						
		for i = 1, nPhotos do
			if progressScope:isCanceled() then break end
			
			local pubPhoto = publishedPhotos[i]
			local publishedPath = pubPhoto:getRemoteId()
			
			if publishedPath ~= nil then PSFileStationAPI.deletePic(publishedPath) end
			nProcessed = i
			progressScope:setPortionComplete(nProcessed, nPhotos)
		end 
		progressScope:done()
		
		timeUsed = 	LrDate.currentTime() - startTime
		timePerPic = nProcessed / timeUsed 			-- pic per sec makes more sense here
		message = LOC ("$$$/PSUpload/Upload/Errors/CheckMoved=" .. 
						string.format("PhotoStation Upload - DeletePublishedCollection: Deleted %d of %d pics in %d seconds (%.1f pics/sec).\n", 
						nProcessed, nPhotos, timeUsed + 0.5, timePerPic))

		showFinalMessage("PhotoStation DeletePublishedCollection done", message, "info")
		closeLogfile()
	end )
	
	closeSession(publishSettings, 'Delete')
end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called (if supplied)  
 -- to retrieve comments from the remote service, for a single collection of photos 
 -- that have been published through this service. .
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.getCommentsFromPublishedCollection( publishSettings, arrayOfPhotoInfo, commentCallback )
	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do

		local comments = FlickrAPI.getComments( publishSettings, {
								photoId = photoInfo.remoteId,
							} )
		
		local commentList = {}
		
		if comments and #comments > 0 then

			for _, comment in ipairs( comments ) do

				table.insert( commentList, {
								commentId = comment.id,
								commentText = comment.commentText,
								dateCreated = comment.datecreate,
								username = comment.author,
								realname = comment.authorname,
								url = comment.permalink
							} )

			end			

		end	

		commentCallback{ publishedPhoto = photoInfo, comments = commentList }						    

	end
end
]]
--------------------------------------------------------------------------------
--- (optional, string) This plug-in defined property allows you to customize the
 -- name of the viewer-defined ratings that are obtained from the service via
 -- <a href="#publishServiceProvider.getRatingsFromPublishedCollection"><code>getRatingsFromPublishedCollection</code></a>.
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.titleForPhotoRating
	-- @class property

publishServiceProvider.titleForPhotoRating = LOC "$$$/PSPublish/TitleForPhotoRating=Photo Rating"

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called (if supplied)
 -- to retrieve ratings from the remote service, for a single collection of photos 
 -- that have been published through this service. This function is called:
  -- <ul>
    -- <li>For every photo in the published collection each time <i>any</i> photo
	-- in the collection is published or re-published.</li>
 	-- <li>When the user clicks the Refresh button in the Library module's Comments panel.</li>
	-- <li>After the user adds a new comment to a photo in the Library module's Comments panel.</li>
  -- </ul>
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.getRatingsFromPublishedCollection( publishSettings, arrayOfPhotoInfo, ratingCallback )

	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do

		local rating = FlickrAPI.getNumOfFavorites( publishSettings, { photoId = photoInfo.remoteId } )
		if type( rating ) == 'string' then rating = tonumber( rating ) end

		ratingCallback{ publishedPhoto = photoInfo, rating = rating or 0 }

	end
end
]]	

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called whenever a
 -- published photo is selected in the Library module. Your implementation should
 -- return true if there is a viable connection to the publish service and
 -- comments can be added at this time. If this function is not implemented,
 -- the new comment section of the Comments panel in the Library is left enabled
 -- at all times for photos published by this service. If you implement this function,
 -- it allows you to disable the Comments panel temporarily if, for example,
 -- the connection to your server is down.
--[[ Not used for PhotoStation Upload plug-in.

function publishServiceProvider.canAddCommentsToService( publishSettings )
	return false
end
]]
--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user adds 
 -- a new comment to a published photo in the Library module's Comments panel. 
 -- Your implementation should publish the comment to the service.
--[[ Not used for PhotoStation Upload plug-in.

 function publishServiceProvider.addCommentToPublishedPhoto( publishSettings, remotePhotoId, commentText )
	return true
end
]]
--------------------------------------------------------------------------------

PSPublishSupport = publishServiceProvider