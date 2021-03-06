class App.Stockists extends App.Base
  map: null,
  marker: null,
  circle: null,
  @zoomLevel: 4,

  index: =>
    $('.calc-btn').click ->
      $('#new_reward_period').submit()

  new: =>
    @initMap()
    @initProductTypes()

    $('#import-csv').on 'click', (e) ->
      e.preventDefault()
      full = location.protocol + '//' + location.hostname + (if location.port then ':' + location.port else '')

      ShopifyApp.Modal.open({
        src: full+'/imports/new',
        title: 'Stockist CSV Import',
        width: 'small',
        height: 300,
        buttons: {
          primary: { label: "OK" }
          secondary: [{
            label: "Cancel", callback: (label) ->
              ShopifyApp.Modal.close()
          }]
        }
      }, (result, data) ->
        alert("result: " + result + "   data: " + data);
      )

  edit: =>
    @initMap()
    @initProductTypes()
    @updateMap()

  show: =>
    @initMapWithOrders()

  initMap: ->
    addressFields = $('#stockist_name, #stockist_address_1, #stockist_address_2, #stockist_state, #stockist_postcode, #stockist_order_radius')
    addressFields.on 'change', @updateMap
    addressFields.on 'input', @updateMap
    e = document.getElementById('map')
    if e != null
      App.Stockists.map = new google.maps.Map e, {center: {lat: 39.50, lng: -98.35}, zoom: App.Stockists.zoomLevel}

  initMapWithOrders: ->
    e = document.getElementById('map')
    if e != null
      App.Stockists.map = new google.maps.Map e, {center: {lat: Utility.RailsVars.stockist.latitude, lng: Utility.RailsVars.stockist.longitude}, zoom: 12}

  updateMap: ->
    zipcode = $("#stockist_postcode").val().substring(0, 5);
    if (zipcode.length == 5 && /^[0-9]+$/.test(zipcode))
      url = "/zipcode/" + zipcode
      $.ajax({"url": url, "dataType": "json"}).done (data) ->
        $("#stockist_city").val(data[0])
        $("#stockist_state").val(data[1])

    a = App.Stockists.getAddress()
    App.Stockists.codeAddress(a)

  initProductTypes: ->
    App.Stockists.setCheckboxes()
    $('.Polaris-Checkbox').on 'click', ->
      $(this).find('.Polaris-Checkbox__Icon').toggleClass('checked')
      App.Stockists.setCheckboxes()

  @setCheckboxes: ->
    if $('#checkbox-restrict-icon').hasClass('checked')
      $('#stockist_restricted').val('true')
      $('#product-types').addClass('shown')
    else
      $('#stockist_restricted').val('false')
      $('#product-types').removeClass('shown')

    $('.product-type-checkbox').each ->
      handle = $(this).attr('id').replace('checkbox-','')
      if $("#checkbox-"+handle+"-icon").hasClass('checked')
        $('#stockist_'+handle).val('true')
      else
        $('#stockist_'+handle).val('false')


  @getAddress: ->
    zl = 4
    address = ''
    if $('#stockist_name').val().length > 0
      address += $('#stockist_name').val()+', '
    if $('#stockist_address_1').val().length > 0
      address += $('#stockist_address_1').val()
      zl++
    if $('#stockist_address_2').val().length > 0
      address += ', '+$('#stockist_address_2').val()
    if $('#stockist_city').val().length > 0
      address += ', '+$('#stockist_city').val()
      zl++
    if $('#stockist_postcode').val().length > 0
      address += ', '+$('#stockist_postcode').val()
      zl+=3
    if $('#stockist_state').val().length > 0
      address += ', '+$('#stockist_state').val()
      zl++
    App.Stockists.zoomLevel = zl
    App.Stockists.map.zoomLevel = zl
    address += ', USA'

  @codeAddress: (address) =>
    geocoder = new google.maps.Geocoder()
    geocoder.geocode({address:address}, @drawCodedAddress)

  @drawCodedAddress: (results, status) ->
    if (status == google.maps.GeocoderStatus.OK)
      App.Stockists.map.setCenter(results[0].geometry.location)
      App.Stockists.map.setZoom(App.Stockists.zoomLevel)

      if App.Stockists.marker != undefined
        App.Stockists.marker.setMap(null)

      App.Stockists.marker = new google.maps.Marker
        position: results[0].geometry.location,
        map: App.Stockists.map,
        title: $('#stockist_name').val()

      r = $('#stockist_order_radius').val()
      if(parseInt(r) != "NaN")

        if App.Stockists.circle != undefined
          App.Stockists.circle.setMap(null)

        if r > 90
          App.Stockists.zoomLevel = 7
        else if r > 45
          App.Stockists.zoomLevel = 8
        else if r > 25
          App.Stockists.zoomLevel = 9
        else
          App.Stockists.zoomLevel = 10

        App.Stockists.map.setZoom(App.Stockists.zoomLevel)

        App.Stockists.circle = new google.maps.Circle({
          strokeColor: '#0000CC',
          strokeOpacity: 0.8,
          strokeWeight: 2,
          fillColor: '#0000FF',
          fillOpacity: 0.35,
          map: App.Stockists.map,
          center: App.Stockists.marker.position,
          radius: parseInt(r)*1000 * 1.60934 # (miles to km)
        });
