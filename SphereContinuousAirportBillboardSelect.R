#clear environment and set up working directory and load libraries
rm(list=ls())
setwd("C:/Users/darryl_2/Desktop/intern 2.0")
source("needs.R")
source("LoadLibraries.R")
source("Functions.R")

#connect to channel (from ODBC)
channel <- odbcConnect("PJ")


#get data from aireon database (from SSMS)
airfull <- sqlQuery(channel, "select * from adsb24h")
events <- sqlQuery(channel, "select * from event")

#function to retrieve targetaddress based on event and airport identity
#let's get all flight which landed at xyz airport CHANGE THIS!
getTarget("gap start","WSSS")
filename<-"SphereContinuousAirportBillboardSelectBug.txt"

#if you want to choose your own aircraft, write a logical named 'target' in the form described below
#target is in the form of a list of aircraft e.g.target <- 0, target[1] <- "76cce7", target[2] <- "75027d"
#the easier way is using getTarget function if u want a list of aircraft which visited an airport


#a little complicated way to obtain all the rows from air containing elements matching those in the target list, used to find time of simulation and draw airports
ortarget<-"\""
for (h in 1:length(target)){
  ortarget<-paste(ortarget,target[h],"|",sep="")
}
ortarget<-gsub('.{1}$', '', ortarget)
ortarget<-paste(ortarget,"\"",sep="")
air <- as.data.frame(airfull[grep(eval(parse(text=ortarget)),unlist(airfull$targetaddress)),])

difftime<-0
stopped<-0

#= t_i - t_(i-1)
for (i in 2:nrow(air)){
  difftime[i] <- as.integer(difftime(air$timestamprecvd[i],air$timestamprecvd[i-1],units="secs"))
}

for (i in 2:(length(difftime)-1)){
  if (difftime[i]>300 | air$targetaddress[i]!=air$targetaddress[i+1]){
    stopped[i]<-1
  }
  else {
    stopped[i]<-0
  }
}
airportfinderfast() #yay can just find nearest airport


#get unique airports
#https://github.com/CesiumGS/cesium/issues/6825 no support for aligning billboard parallel to ground
#added if statement as some flights do not have any gap start/gap end for which we calculate the nearest airport.
z<-NULL
e<-unique(as.data.frame(air[air$nearestairport!=0,c("nearestairport","apotlong","apotlat")]))
if (nrow(e)>0){  
  for (i in 1:nrow(e)){
    z <- paste(z,"var airport_",i, "= viewer.entities.add({
      name : \"",gsub("\"","'",e$nearestairport[i]), "\",
               position : Cesium.Cartesian3.fromDegrees(", e$apotlong[i], ",", e$apotlat[i], "),
               billboard : {
                  image : 'https://tr.rbxcdn.com/0905c45a9115a33f517718f66a739b5f/420/420/Decal/Png',
                  alignedAxis: Cesium.Cartesian3.UNIT_Z,
                  scaleByDistance : new Cesium.NearFarScalar(0, 0.2, 8.0e6, 0.0)
          }
      });
  ", sep="")
  }
}


#let's write our flight start(1st timestamp)/end(last timestamp) times.
#note we are using SINGAPORE timezone(?)..
x<-paste("var czml = [{
  id : 'document',
  version : '1.0',
  clock: {
      interval: '",as.Date(as.POSIXct(min(air$timestamprecvd)),tz='Singapore'),"T",strftime(min(air$timestamprecvd), format='%H:%M:%S'),"Z/",as.Date(as.POSIXct(max(air$timestamprecvd)),tz='Singapore'),"T",strftime(max(air$timestamprecvd), format='%H:%M:%S'),"Z',
      currentTime: '",as.Date(as.POSIXct(min(air$timestamprecvd)),tz='Singapore'),"T",strftime(min(air$timestamprecvd), format='%H:%M:%S'),"Z',
      multiplier: 50
  }
}, ",sep="")
write(x,filename, append = FALSE) #write a new file with just the initial czml function

for (i in 1:length(target)){
  air <- as.data.frame(airfull[grep(target[i],unlist(airfull$targetaddress)),])
  simtime<-difftime(air$timestamprecvd[nrow(air)],air$timestamprecvd[1],units="secs")
  mysplitter() #yay we can just split into seperate flights
  airportfinder() #yay can just find nearest airport
  
  if (max(air$splitted)>1){
    for (j in 1:(max(air$splitted)-1)){
      x<-NULL #we wanna reset x everytime we write the next flight
      miniair<-eval(parse(text=paste("air",j,sep=""))) #oh no we gotta evaluate text strings.. here's an example
      timenextflight <-eval(parse(text=paste("air",j+1,"$timestamprecvd[1]",sep="")))
      a<-nrow(miniair) 
      b<-NULL
      c<-hour(miniair$timestamprecvd[i])/23 #we use the hour component of 1st row to write color
      d<-0 #the initial time based on 'availability'
      for (k in 1:a){
        b<-paste(b,d,",",miniair$longitude[k], ", ", miniair$latitude[k], ", ", miniair$flightlevel[k]*30.48, ",
             ", sep="")
        d<-d+miniair$difftime[k+1]
      }
      b<-paste(b,difftime(timenextflight,miniair$timestamprecvd[1],units = "secs"),",",miniair$longitude[a], ", ", miniair$latitude[a], ", ", miniair$flightlevel[a]*30.48, sep="")
      #nice, we have our cartographicdegrees as b
      #we can fill in the rest of the czml stuff
      
      x<-paste(x,"{
    name : '", gsub("'","",miniair$targetaddress[1]),"_",j, "',
    availability : '",as.Date(as.POSIXct(air$timestamprecvd[1]),tz='Singapore'),"T",strftime(air$timestamprecvd[1], format='%H:%M:%S'),"Z/",as.Date(as.POSIXct(air$timestamprecvd[nrow(air)]),tz='Singapore'),"T",strftime(air$timestamprecvd[nrow(air)], format='%H:%M:%S'),"Z',
    path : {
        material : {
            polylineGlow : {
                color : {
                    rgbaf : [",(abs(3-6*c)-1),",",(-abs(2-6*c)+2),",",(-abs(4-6*c)+2),"]
                }
            }
        },
        width : 5,
    },
    billboard : {
        image : 'https://res.cloudinary.com/dk-find-out/image/upload/q_80,w_960,f_auto/sphere_n69vel.png',
        scaleByDistance : {
            nearFarScalar: [ 0, 0.05, 8.0e6, 0.0 ]
        },
        eyeOffset: {
            cartesian: [ 0.0, 0.0, -10.0 ]
        }
    },
    position : {
        epoch : '",as.Date(as.POSIXct(miniair$timestamprecvd[1]),tz='Singapore'),"T",strftime(miniair$timestamprecvd[1], format='%H:%M:%S'),"Z',
        cartographicDegrees : [",
               b,"
        ]
    }
  }, ",sep="")
    
    write(x,filename, append = TRUE)
    }
  }
  i<-max(air$splitted)
  x<-NULL #we wanna reset x everytime we write the next flight
  miniair<-eval(parse(text=paste("air",i,sep=""))) #oh no we gotta evaluate text strings.. here's an example
  a<-nrow(miniair) 
  b<-NULL
  c<-hour(miniair$timestamprecvd[i])/24 #we use the hour component of 1st row to write color
  d<-0 #the initial time based on 'availability'
  for (j in 1:a){
    b<-paste(b,d,",",miniair$longitude[j], ", ", miniair$latitude[j], ", ", miniair$flightlevel[j]*30.48, ",
       ", sep="")
    d<-d+miniair$difftime[j+1]
  }
  b<-paste(b,simtime,",",miniair$longitude[a], ", ", miniair$latitude[a], ", ", miniair$flightlevel[a]*30.48, sep="")
  #nice, we have our cartographicdegrees as b
  #we can fill in the rest of the czml stuff
  
  x<-paste(x,"{
name : '", gsub("'","",miniair$targetaddress[1]),"_",i, "',
availability : '",as.Date(as.POSIXct(air$timestamprecvd[1]),tz='Singapore'),"T",strftime(air$timestamprecvd[1], format='%H:%M:%S'),"Z/",as.Date(as.POSIXct(air$timestamprecvd[nrow(air)]),tz='Singapore'),"T",strftime(air$timestamprecvd[nrow(air)], format='%H:%M:%S'),"Z',
path : {
  material : {
      polylineGlow : {
          color : {
              rgbaf : [",(abs(3-6*c)-1),",",(-abs(2-6*c)+2),",",(-abs(4-6*c)+2),"]
          }
      }
  },
  width : 5,
},
billboard : {
  image : 'https://res.cloudinary.com/dk-find-out/image/upload/q_80,w_960,f_auto/sphere_n69vel.png',
  scaleByDistance : {
      nearFarScalar: [ 0, 0.05, 8.0e6, 0.0 ]
  },
  eyeOffset: {
      cartesian: [ 0.0, 0.0, -10.0 ]
  }
},
position : {
  epoch : '",as.Date(as.POSIXct(miniair$timestamprecvd[1]),tz='Singapore'),"T",strftime(miniair$timestamprecvd[1], format='%H:%M:%S'),"Z',
  cartographicDegrees : [",
           b,"
  ]
}
}, ",sep="")
  write(x,filename, append = TRUE)
}



#remove the last comma
y<-read_file(filename)
y<-gsub("\r\n","\n",y)
y<-gsub('.{3}$', '', y)
write(y,filename)



#add the viewer and airports
x<-NULL
x<-paste(x,"];
var viewer = new Cesium.Viewer('cesiumContainer', {
    terrainProvider : Cesium.createWorldTerrain(),
    baseLayerPicker : false,
    shouldAnimate : true
});

viewer.dataSources.add(Cesium.CzmlDataSource.load(czml)).then(function(ds) {});
",sep="")
write(x,filename,append=TRUE)
write(z,filename,append=TRUE)


