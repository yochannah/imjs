# This module supplies the **List** class for the **im.js**
# web-service client.
#
# Lists are representations of collections of objects stored
# on the server.
#
# This library is designed to be compatible with both node.js
# and browsers.

IS_NODE = typeof exports isnt 'undefined'
__root__ = exports ? this

if IS_NODE
    {_} = require 'underscore'
    funcutils = require './util'
    intermine = __root__
else
    {_, intermine}  = __root__
    {funcutils}     = intermine

{get, invoke, REQUIRES_VERSION, set, dejoin} = funcutils

TAGS_PATH = "list/tags"
SHARES = "lists/shares"
INVITES = 'lists/invitations'

isFolder      = (t) -> t.substr(0, t.indexOf(':')) is '__folder__'
getFolderName = (t) -> s.substr(t.indexOf(':') + 1)

# A representation of collections of objects stored in a data-warehouse.
#
# Lists can be created through the list upload mechanism (Service#createList) and
# the query saving mechanism (Query#saveAsList).
class List

    # Construct a new list.
    #
    # @param [Object] properties The properties of this list.
    # @option properties [String] name The name of this list.
    # @option properties [Number] size The size of this list.
    # @option properties [Number] dateCreated The timestamp of the creation date for this list.
    # @option properties [String] description The description of this list.
    # @option properties [tags] The tags for this list.
    # @param [Service] service The service this list belongs to.
    constructor: (properties, @service) ->
        for own k, v of properties
            @[k] = v
        @dateCreated = if (@dateCreated?) then new Date(@dateCreated) else null

        @folders = @tags.filter(isFolder).map(getFolderName)

    # Whether or not this list has a certain tag.
    #
    # @param [String] t The tag this list is meant to have.
    # @return [boolean] true if this list has the certain tag.
    hasTag: (t) -> t in @tags

    # Construct a query for data contained in this list.
    #
    # @param [Array<String>] view An optional list of output columns.
    #   Defaults to the summary fields for objects of this type.
    # @return [Promise<Query>] A promise to yield a query.
    query: (view = ['*']) -> @service.query select: view, from: @type, where: [[@type, 'IN', @name]]

    del: (cb) -> @service.makeRequest 'DELETE', 'lists', {@name}, cb

    # Get the contents of this list.
    #
    # The dejoin function is used to ensure that all objects in the list are returned, and
    # we don't miss out on any due to the implicit constraints of inner joins.
    #
    # @param [(Array<Object>) ->] cb A function that receives a list of objects. Optional.
    # @return [Promise<Array<Object>>] A promise to yield a list of objects.
    contents: (cb) -> @query().pipe(dejoin).pipe(invoke 'records').done(cb)

    # Rename this list. Upon resolution of this actions promise, this object will have its
    # name property set to the new value.
    #
    # @param [String] newName The name this list should have.
    # @param [(String) ->] cb A function that receives a string. optional.
    # @return [Promise<String>] A promise to yield a name (the name this list now has).
    rename: (newName, cb) -> @service.post('lists/rename', oldname: @name, newname: newName)
                                     .pipe(get 'listName').done((n) => @name = n)
                                     .done(cb)

    # Copy this list to an exact duplicate with a different name.
    #
    # This function will check that any name given does not collide with any other
    # list you have access to, adding a suffix to avoid name clashes. This means you should
    # probably check the yielded value to see what name it ended up with.
    #
    # @param [String] name The name to copy this list as. Optional. Defaults to @name + _copy.
    # @param [(List) ->] cb An optional function that receives a List.
    # @return [Promise<List>] A promise to yield a list.
    copy: (name, cb) ->
        name = baseName = (name ? "#{ @name }_copy")
        query = @query ['id']
        @service.fetchLists().pipe(invoke 'map', get 'name').pipe (names) =>
            c = 1
            while name in names
                name = "#{ baseName }-#{ c++ }"
            query.pipe(invoke 'saveAsList', {name, @tags, @description}).done(cb)

    # Fetch the results for a particular enrichment calculation
    # against this list. See Service#enrichment.
    #
    # @param [Object] opts The parameters of this request.
    # @option opts [String] widget The calculation to run.
    # @option opts [Number] maxp The maximum permissible p-value (optional, default = 0.05).
    # @option opts [String] correction The correction algorithm to use (default = Holm-Bonferroni).
    # @option opts [String] population The name of a list to use as a background
    #   population (optional).
    # @option opts [String] filter An extra value that some widget calculations accept.
    # @param [->] cb A function to call with the results when they have been received (optional).
    # @return [Promise<Array<Object>>] A promise to get results.
    enrichment: (opts, cb) -> @service.enrichment(((set list: @name) opts), cb)

    # Share this list with a recipient.
    #
    # The recipient should exist as a user in the target InterMine instance.
    #
    # @param [String] recipient The identifier of a user.
    # @param [->] cb A function to call on successful completion (optional).
    # @return [Promise<>] A promise to share a List.
    shareWithUser: (recipient, cb) ->
        # TODO - tests
        @service.post(SHARES, list: @name, with: recipient).done(cb)

    # Invite a user to share this list.
    #
    # @param [String] recipient The email address of someone to invite to share this list.
    # @param [boolean] notify Whether or not to notify the recipient by email.
    # @param [->] cb A function to call upon successful completion.
    #
    # @return [Promise<>] A promise to invite a user to share a list.
    inviteUserToShare: (recipient, notify = true, cb = (->)) ->
        # TODO - tests
        @service.post(INVITES, list: @name, to: recipient, notify: !!notify).done(cb)

intermine.List = List




