rm(list=ls())
setwd("C:\\Users\\darryl_2\\Desktop\\intern 2.0")
source("needs.R")
source("LoadLibraries.R")

channel <- odbcConnect("PJ")



x<-'[{
    "id" : "document",
    "name" : "CZML Geometries: Polyline",
    "version" : "1.0"
},'
air <- sqlQuery(channel, "select * from Aireon.dbo.Q050ADSBDense300")
z<-max(air$my_dense_rank)
for (i in 1:(z-1)){
  air1<-sqlQuery(channel, paste("select * from Aireon.dbo.Q050ADSBDense300 where my_dense_rank=",i))
  a <- nrow(air1)
  b<-NULL
  for (j in 1:(a-1)){
    b<-paste(b,air1$longitude[j], ', ', air1$latitude[j], ', ', air1$geometricheightfeet[j], ',
           ', sep="")
  }
  b<-paste(b,air1$longitude[a], ', ', air1$latitude[a], ', ', air1$geometricheightfeet[a], sep="")
  x<-paste(x,' {
  "id" : "', gsub("'","",air1$targetaddress[1]),'",
  "name" : "',gsub("'","",air1$targetaddress[1]),'",
  "polyline" : {
        "positions" : {
            "cartographicDegrees" : [
                ', b, '
            ]
        },
        "material" : {
            "polylineGlow" : {
                "color" : {
                    "rgba" : [100, 149, 237, 255]
                },
                "glowPower" : 0.2,
                "taperPower" : 0.8
            }
        },
        "width" : 8
    }
},
',sep="")
}

air1<-sqlQuery(channel, paste("select * from Aireon.dbo.Q050ADSBDense300 where my_dense_rank=",z))
a <- nrow(air1)
b<-NULL
for (j in 1:(a-1)){
  b<-paste(b,air1$longitude[j], ', ', air1$latitude[j], ', ', air1$geometricheightfeet[j], ',
           ', sep="")
}
b<-paste(b,air1$longitude[a], ', ', air1$latitude[a], ', ', air1$geometricheightfeet[a], sep="")
x<-paste(x,' {
  "id" : "', gsub("'","",air1$targetaddress[1]),'",
  "name" : "',gsub("'","",air1$targetaddress[1]),'",
  "polyline" : {
        "positions" : {
            "cartographicDegrees" : [
                ', b, '
            ]
        },
        "material" : {
            "polylineGlow" : {
                "color" : {
                    "rgba" : [100, 149, 237, 255]
                },
                "glowPower" : 0.2,
                "taperPower" : 0.8
            }
        },
        "width" : 8
    }
}
]
',sep="")


write(x,"polyline.czml")
