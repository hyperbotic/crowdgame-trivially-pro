String::singularize = ()->
String::pluralize = ()->this+"s"
String::camelize = ()->this.replace(/_([a-z])/g, $1.toUpperCase())
String::underscore = ()->this.replace(/([a-zA-Z])([A-Z])/g, "$1_$2").toLowerCase()
String::tabelize = ()->this.pluralize().underscore()
