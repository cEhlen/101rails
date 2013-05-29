class Wiki.Views.ExTriple extends Backbone.View
  resourceTemplate : JST['backbone/templates/resource']
  resourceBoxTemplate : JST['backbone/templates/resourcebox']

  prefixToName : {  'www.haskell.org': 'HaskellWiki', 'en.wikipedia.org': 'Wikipedia', 'en.wikibooks.org': 'Wikibooks', 'www.youtube.com': "YouTube", 'github.com': 'GitHub'}
  # which parts of the '/'-split of the URL to show
  prefixToSplit : {'github.com': {'pick': [4], 'tail': 7}}

  decode: (str, toLower) ->
    self = @
    resBase = "http://101companies.org/resource/"
    str = decodeURIComponent(str.replace(resBase,"").replace(/-3A/g,":").replace("Property:", "").replace(/_/g, " "))
    split = str.split("/")
    key = split[2].trim()
    if key of @prefixToSplit
      str = split.filter((x,i) -> _.contains(self.prefixToSplit[key].pick, i)).join('/')
      str += '/' + split.slice(@prefixToSplit[key].tail).join('/')
    else
      str = _.last(split)
      if str.replace(/\s/g, '') == ''
        str = split[split.length - 2]
    if toLower
      firstLetter = str.substr(0, 1)
      firstLetter.toLowerCase() + str.substr(1)
    else
      str

  render: ->
    self = @
    key = @model.get('node').split('/')[2]
    if key of @prefixToName
      fullName = @prefixToName[key]
    else
      fullName = key
    $('#resources').show()
    place = $('#resources').find('.' + fullName)
    info = {'full' : @model.get('node'), 'chapter': @decode(@model.get('node'), false)}
    if place.length
      $(place).find('.resourcebar').append($(self.resourceBoxTemplate(cat:'primary', link:info, predicate: @decode(@model.get('predicate')))).tooltip("show"))
    else
      @setElement($(@resourceTemplate(fullName: fullName, name: fullName.replace(/\w/, ''))))
      $(@el).find('.resourcebar').append($(self.resourceBoxTemplate(cat:'primary', link:info, predicate: @decode(@model.get('predicate')))).tooltip("show"))
      $('#resources').append(@el)
      $(@el).find('.resourcename').mouseenter( ->
        $(self.el).find('.resourcebar').first().collapse('show')
      )
      $(@el).mouseleave(
        -> $(self.el).find('.resourcebar').first().collapse('hide')
      )
