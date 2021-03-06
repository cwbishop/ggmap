#' Reverse geocode
#'
#' reverse geocodes a longitude/latitude location using Google Maps.
#' Note that in most cases by using this function you are agreeing
#' to the Google Maps API Terms of Service at
#' https://developers.google.com/maps/terms.
#'
#' @param location a location in longitude/latitude format
#' @param output amount of output
#' @param messaging turn messaging on/off
#' @param sensor whether or not the geocoding request comes from a
#'   device with a location sensor
#' @param override_limit override the current query count
#'   (.GoogleGeocodeQueryCount)
#' @param client client ID for business users, see
#'   https://developers.google.com/maps/documentation/business/webservices/auth
#'
#' @param signature signature for business users, see
#'   https://developers.google.com/maps/documentation/business/webservices/auth
#'
#' @param source source to use for reverse geocoding
#' 
#' @return depends (at least an address)
#' @details note that the google maps api limits to 2500 queries a
#'   day.
#' @author David Kahle \email{david.kahle@@gmail.com}
#' @seealso
#'   \url{http://code.google.com/apis/maps/documentation/geocoding/}
#' @export
#' @examples
#'
#' \dontrun{ # Server response can be slow; this cuts down check time.
#'
#' ( gc <- as.numeric(geocode('Baylor University')) )
#' revgeocode(gc)
#' revgeocode(gc, output = 'more')
#' revgeocode(gc, output = 'all')
#' geocodeQueryCheck()
#'
#' }
#'
revgeocode <- function(location, output = c('address','more','all'),
  messaging = FALSE, sensor = FALSE, override_limit = FALSE,
  client = "", signature = "", source = c('google', 'osm')
){

  # check parameters
  stopifnot(is.numeric(location) && length(location) == 2)
  output <- match.arg(output)
  source <- match.arg(source)
  stopifnot(is.logical(messaging))
  stopifnot(is.logical(sensor))

  # Only relevant for google. Might need to add in a clause for OSM
  if(client != "" && signature != ""){
  	if(substr(client, 1, 4) != 'gme-') client <- paste("gme-", client, sep = "")
  	userType <- "business"
  } else if(client == "" && signature != ""){
    stop("if signature argument is specified, client must be as well.", call. = FALSE)
  } else if(client != "" && signature == ""){
    stop("if client argument is specified, signature must be as well.", call. = FALSE)
  } else {
    userType <- "free"
  }

  # format url
  if(sensor){ sensor <- 'true' } else { sensor <- 'false' }
  sensor4url <- paste('&sensor=', sensor, sep = '') # includes &
  client4url <- paste('&client=', client, sep = '')
  signature4url <- paste('&signature=', signature, sep = '')
  
  if(source == "osm"){
    laturl <- paste('lat=', location[2], sep = "")
    lonurl <- paste('&lon=', location[1], sep = "")
  
    loc4url <- paste(laturl, lonurl, sep="")
    url_string <- paste("http://nominatim.openstreetmap.org/reverse?", loc4url, '&format=json', sep = "")

  }else{
    loc4url <- paste(rev(location), collapse = ',')
    url_string <- paste("http://maps.googleapis.com/maps/api/geocode/json?latlng=",
      loc4url, sensor4url, sep = "")
  }

  
  if(userType == "business"){
    url_string <- paste(url_string, client4url, signature4url, sep = "")
  }
  url_string <- URLencode(url_string)

  # check/update google query limit
  check <- checkGeocodeQueryLimit(url_string, elems = 1,
    override = override_limit, messaging = messaging, userType = userType)
    if(check == "stop"){
      if(output == "address"){
        return(NA)
      } else if(output == "more") {
        return(c(address = NA, street_number = NA, route = NA,
          locality = NA, administrative_area_level_2 = NA,
          administrative_area_level_1 = NA, country = NA, postal_code = NA)
        )
      } else {
        return(NA)
      }
    }

  # geocode
  connect <- url(url_string)
  rgc <- fromJSON(paste(readLines(connect, warn = FALSE), collapse = ''))
  close(connect)
  if(output == 'all') return(rgc)

  # did geocode fail?
  post_warning <- FALSE
  if(source == "osm" & !is.null(rgc$error)){
    post_warning <- TRUE
  } else if(source != "osm"){
    if(rgc$status != 'OK'){
      post_warning <- TRUE
    }
  }
  
  if(post_warning){
    warning(paste('reverse geocode failed - bad location? location = "',
                  location, '"', sep = ''))
    return(data.frame(address = NA))
  }

  # message user
  message(paste0('Information from URL : ', url_string))

  # more than one location found?
  if(length(rgc$results) > 1 && messaging){
    message(paste('more than one location found for "', location,
      '", reverse geocoding first...\n', sep = ''))
  }

  # Coerce OSM results to match Google
  #   Little "hacky" but minimizes code rewriting
  if(source == "osm"){
    rgc$formatted_address <- rgc$display_name
  }else{
    # format
    rgc <- rgc$results[[1]]
  }
  
  # If user wants just the address, return the address!
  if(output == 'address') return(rgc$formatted_address)

  with(rgc,{rgcdf <<- data.frame(
    address = formatted_address
  )})

  # Requires a bit of special handling for OSM returns
  if(source == "osm"){
  
    rgcdf <- cbind(rgcdf, as.data.frame(rgc$address))
  
  }else{
    
    for(k in seq_along(rgc$address_components)){
    	rgcdf <- cbind(rgcdf, rgc$address_components[[k]]$long_name)
    }
    
    names(rgcdf) <- c('address', sapply(rgc$address_components, function(l) l$types[1]))
  
  }
  
  # return 'more' output
  rgcdf

}
