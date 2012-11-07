# A simple class to manage stored configuration with defaults.
class Config
  serviceCollections:
    'delicious': DeliciousCollection
    'pinboard': PinboardCollection

  constructor: ->
    @loaded = browser.storage.getItem('config')
    @loaded.then (config) =>
      data = if config? then JSON.parse(config) else {}
      @service = data.service or 'delicious'
      @username = data.username
      @password = data.password
      @validCredentials = data.validCredentials or false
      @private = data.private or false

  checkCredentials: (callback) ->
    bookmarks = @createCollection()
    bookmarks.isAuthValid (valid) =>
      @validCredentials = valid
      callback(valid)

  save: ->
    browser.storage.setItem 'config', JSON.stringify
      service: @service
      username: @username
      password: @password
      validCredentials: @validCredentials
      private: @private

  # Create a collection instance using the class defined by `service`.
  createCollection: ->
    throw 'config not loaded' unless @loaded.isResolved()
    new @serviceCollections[@service] [],
      username: @username
      password: @password
