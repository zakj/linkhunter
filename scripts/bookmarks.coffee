## CachedCollection

# A Backbone `Collection` backed by a local cache; it also tracks the timestamp
# of its last update from its authoritative data source.
class CachedCollection extends Backbone.Collection
  # Subclasses must include a `name` attribute, to be used as the local cache
  # item's key.
  name: undefined

  # When the collection's data is reset, also update the cache. If no models
  # are passed to `initialize`, initialize from the cache. Manage a @loaded
  # promise to notify users when all required data has loaded from storage.
  initialize: (models, options) ->
    d = new $.Deferred
    @loaded = d.promise()
    needModels = false
    needUpdated = true
    resolve = => d.resolve() unless needModels or needUpdated
    unless models.length
      needModels = true
      browser.storage.getItem(@name).then (store) =>
        if store
          @models = (new @model(obj) for obj in JSON.parse(store))
        needModels = false
        resolve()
        @trigger('reset')
    @_lastUpdatedKey = "#{@name}:lastUpdated"
    browser.storage.getItem(@_lastUpdatedKey).then (lastUpdated) =>
      @lastUpdated = moment(lastUpdated or 0)
      @lastUpdated = moment(0) if isNaN(@lastUpdated)
      needUpdated = false
      resolve()

  # Update the local cache each time the remote models are fetched.
  fetch: (options) =>
    super(options).then @_updateCache

  # Save the collection's models to the cache.
  _saveCache: =>
    browser.storage.setItem(@name, JSON.stringify(@models))

  # Save the models and a new last-updated timestamp.
  _updateCache: =>
    @_saveCache()
    @lastUpdated = moment()
    browser.storage.setItem(@_lastUpdatedKey, @lastUpdated.native())


## Bookmark

class Bookmark extends Backbone.Model

  defaults: ->
    'time': new Date

  # Since bookmarks are not backed by a `Backbone.sync`-friendly API, all saves
  # should happen through the `create` method of `BookmarkCollection`
  # subclasses.
  save: -> throw 'Use BookmarkCollection.create instead'


## BookmarkCollection

# Superclass for cloud bookmark service backends. Subclasses should set `url`
# and `parse` as usual for Backbone collections.
class BookmarkCollection extends CachedCollection
  name: 'bookmarks'
  model: Bookmark
  # Chosen mostly arbitrarily.
  maxResults: 100

  # Subclasses should implement a `fetchIfStale` method. It must call `fetch`
  # if the remote data has been updated since `@lastUpdated`.
  fetchIfStale: -> throw 'Not implemented'
  # Subclasses should implement an `isAuthValid` method. It must accept one
  # callback argument, calling it with a boolean reporting whether the given
  # username and password are correct.
  isAuthValid: (callback) -> throw 'Not implemented'
  # Subclasses should implement a `create` method which takes a model (or
  # model-like object), creates it via the appropriate API calls, and adds it
  # to the collection.
  create: (model) -> throw 'Not implemented'
  # Subclasses may set an ajaxOptions attribute, which will be passed to
  # `fetch`. This is mostly useful for controlling `dataType` in one place.
  ajaxOptions: {}
  # Subclasses may implement a `suggestTags` method which takes a URL and a
  # callback. The `suggestTags` should call the callback with an array of tags
  # as the only argument.

  # Set up reusable settings for calls to `jQuery.ajax`.
  initialize: (models, options) ->
    super(models, options)
    @settings = _.defaults options, @ajaxOptions,
      error: (a, b) =>
        # This handler may be called by either Backbone or jQuery, with
        # different parameters.
        status = a.status or b.status
        @trigger('syncError', status)
    # Chrome 19 no longer honors HTTP Basic Auth passed in the URL (which is
    # what jQuery does when you pass it the username/password parameters).
    # Convert here to an Authorization header and remove the username/password
    # params for clarity in the debugger.
    if options.username and options.password
      base64 = btoa([options.username, options.password].join(':'))
      @settings.beforeSend = (xhr) ->
        xhr.setRequestHeader('Authorization', "Basic #{base64}")
      delete @settings.username
      delete @settings.password

  # Sort by most-recent first.
  comparator: (bookmark) ->
    return - Date.parse(bookmark.get('time'))

  fetch: (options = {}) ->
    super(_.defaults(options, @settings))

  # Handle re-adding an existing bookmark, or delegate to the superclass's
  # `add`.
  add: (model, options) ->
    # Detect an existing bookmark by matching the URL. If one exists, just
    # update it with the new model's attributes. Otherwise, add as usual.
    previous = @find (bookmark) -> model.get('url') is bookmark.get('url')
    if previous
      previous.set(model.attributes)
    else
      super(model, options)

  # Return a list of the most recent bookmarks.
  recent: (n = @maxResults) =>
    @first(n)

  # Return a list of matching bookmarks.
  search: (query) =>
    # Words in the query string are separated by whitespace and/or commas. A
    # bookmark must match all given words to be considered a valid result.
    regexps = (new RegExp(word, 'i') for word in query.split(/[, ]+/))
    # Limit the results to `maxResults`; abuse `_.detect` for this purpose
    # because there's no way to exit early from `_.filter` and there's no point
    # traversing thousands of bookmarks once we've already found `maxResults`.
    results = []
    @detect (m) =>
      # Search through both tags and title.
      s = m.get('tags') + m.get('title')
      results.push(m) if _.all(regexps, (re) -> re.test(s))
      return results.length >= @maxResults
    return results

  # Tags are stored as a simple string on each bookmark. Split each
  # bookmark's tag list (if any) into its component tags, and flatten the
  # result into a single list. Then count uses of each tag, and return a list
  # of unique tags in descending order of usage.
  uniqueTags: ->
    _.chain(@pluck('tags'))
      .without('')
      .map((tags) -> tags.split(' ')).flatten()  # TODO delimiter
      .countBy((t) -> t)
      .pairs().sortBy((pair) -> pair[1]).pluck(0)
      .reverse().value()


## DeliciousCollection

# <http://www.delicious.com/help/api>
class DeliciousCollection extends BookmarkCollection
  idAttribute: 'hash'
  url: 'https://api.del.icio.us/v1/posts/all?results=10000'
  ajaxOptions:
    dataType: 'xml'
  updateUrl: 'https://api.del.icio.us/v1/posts/update'
  addUrl: 'https://api.del.icio.us/v1/posts/add'
  suggestUrl: 'https://api.del.icio.us/v1/posts/suggest'
  lastUpdateCheckKey: "bookmarks:lastUpdateCheck"
  lastUpdateCheckInterval: 10

  parse: (resp) ->
    _.map resp.getElementsByTagName('post'), (post) ->
      hash: post.getAttribute('hash')
      title: post.getAttribute('description')
      url: post.getAttribute('href')
      tags: post.getAttribute('tag')
      time: post.getAttribute('time')
      private: post.getAttribute('shared') is 'no'

  fetchIfStale: ->
    settings = _.extend _.clone(@settings),
      success: (data) =>
        @fetch() if moment($(data).find('update').attr('time')) > @lastUpdated
    # The API call to `updateUrl` is rate limited, so we add an extra layer of
    # limiting here.
    now = moment()
    browser.storage.getItem(@lastUpdateCheckKey).then (lastCheck) =>
      lastCheck = moment(lastCheck or 0)
      return if now.diff(lastCheck, 'seconds') < @lastUpdateCheckInterval
      browser.storage.setItem(@lastUpdateCheckKey, now.native())
      $.ajax(@updateUrl, settings)

  isAuthValid: (callback) ->
    # Only attempt the ajax call if we've set up an auth header.
    if @settings.beforeSend
      settings = _.extend _.clone(@settings),
        dataType: 'xml'
        success: (data) -> callback(true)
        error: (data) -> callback(false)
      $.ajax(@updateUrl, settings)
    else
      _.defer(-> callback(false))

  create: (model, options) ->
    model = @_prepareModel(model)
    return false unless model
    data = model.toJSON()
    data.description = data.title
    data.shared = 'no' if data.private
    data.replace = 'yes'
    settings = _.extend _.clone(@settings),
      data: data
      complete: options.complete
      success: (data) =>
        result = data.getElementsByTagName('result')[0].getAttribute('code')
        if result is 'done'
          @add(model)
          @_saveCache()
          options.success?()
        else
          options.error?(result)
    settings.error = options.error if options.error?
    $.ajax(@addUrl, settings)
    return model

  suggestTags: (url, callback) ->
    settings = _.extend _.clone(@settings),
      data: {url: url}
      success: (data) =>
        callback(_.uniq(@parseSuggestedTags(data)))
    $.ajax(@suggestUrl, settings)

  parseSuggestedTags: (resp) ->
    _.map $(resp).find('popular, recommended, network'), (node) ->
      node.getAttribute('tag')


## PinboardCollection

# Mostly matches `DeliciousCollection`.
# <http://pinboard.in/api>
class PinboardCollection extends DeliciousCollection
  url: 'https://api.pinboard.in/v1/posts/all?format=json'
  updateUrl: 'https://api.pinboard.in/v1/posts/update'
  addUrl: 'https://api.pinboard.in/v1/posts/add'
  suggestUrl: 'https://api.pinboard.in/v1/posts/suggest'
  ajaxOptions: {}

  parse: (resp) ->
    _.map resp, (post) ->
      hash: post.hash
      url: post.href
      title: post.description
      tags: post.tags
      time: post.time
      private: post.shared is 'no'

  parseSuggestedTags: (resp) ->
    _.map $(resp).find('popular, recommended'), (node) ->
      node.textContent
