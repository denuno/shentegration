<cfcomponent name="cfantrunner">

	<!--- Meta data --->
	<cfset this.metadata.attributetype="fixed">
    <cfset this.metadata.attributes={
		antfile:			{required:false,type:"string",default:""},
		basedir:			{required:false,type:"string",default:""},
		properties:			{required:false,type:"struct"},
		action:			{required:false,type:"string",default:"runTarget"},
		target:			{required:false,type:"string",default:""},
		logLevel: {required:false,type:"string",default:"MSG_INFO"},
		resultsVar: {required:false,type:"string",default:"runResults"}
		//MSG_ERR, MSG_WARN, MSG_INFO, MSG_VERBOSE, MSG_DEBUG

		}/>

    <cffunction name="init" output="no" returntype="void" hint="invoked after tag is constructed">
    	<cfargument name="hasEndTag" type="boolean" required="yes">
      	<cfargument name="parent" type="component" required="no" hint="the parent cfc custom tag, if there is one">
				<cfset var libs = "" />
				<cfset variables.hasEndTag = arguments.hasEndTag />
  	</cffunction>

    <cffunction name="onStartTag" output="yes" returntype="boolean">
   		<cfargument name="attributes" type="struct">
   		<cfargument name="caller" type="struct">
			<cfscript>
			var buildFile = attributes.antfile;
			var baseDir = attributes.baseDir;
			var project = createObject("java","org.apache.tools.ant.Project");
			var projectHelper = createObject("java","org.apache.tools.ant.ProjectHelper");
			// org.apache.tools.ant.XmlLogger
			var runLogger = createObject("java","org.apache.tools.ant.DefaultLogger");
			var targetName = attributes.target;
			var prop = "";
			var x = 0;
			var runResults = structNew();
			var outStream = createObject("java","java.io.ByteArrayOutputStream").init();
			var errStream = createObject("java","java.io.ByteArrayOutputStream").init();
			var outPrint = createObject("java","java.io.PrintStream").init(outStream);
			var errPrint = createObject("java","java.io.PrintStream").init(errStream);
			if(baseDir == "") {
				basedir = getDirectoryFromPath(buildFile);
			}

			setRailoLoaderClassPath();
			system = createObject("java","java.lang.System");
			system.setProperty("ant.reuse.loader","true");
			//request.debug(system.getProperties());
			project.setCoreLoader(getPageContext().getConfig().getClassLoader());


			project.init();
			if(attributes.action eq "getTargets") {
				caller[attributes.resultsVar] = project.getTargets();
				continue;
			}

// thread = createObject("java","java.lang.Thread");
//			project.setCoreLoader(this.getClass().getClassLoader());
			project.setSystemProperties();
//path = createObject("java","org.apache.tools.ant.types.Path").init(project);
//loader = project.createClassLoader(path);
//        project.setCoreLoader( loader);

//     project.setCoreLoader(Thread.getClass().getClassLoader());
//     project.setCoreLoader(null);
//     project.setCoreLoader(this.getClass().getClassLoader());
//     project.setCoreLoader(Thread.currentThread().getContextClassLoader().getParent());

			// total hack until classloading fun is done
			addTaskByName(project,"all");
			path = createObject("java","org.apache.tools.ant.types.Path").init(project);
//     	project.setCoreLoader(path.getClass().getClassLoader());

			path.addJavaRuntime();
 			project.addDataTypeDefinition("path",path.getClass());
/*
 			project.addTaskDefinition("delete",createObject("java","org.apache.tools.ant.taskdefs.Delete").getClass());
			project.addTaskDefinition("property",createObject("java","org.apache.tools.ant.taskdefs.Property").getClass());
			project.addTaskDefinition("zip",createObject("java","org.apache.tools.ant.taskdefs.Zip").getClass());
			project.addTaskDefinition("java",createObject("java","org.apache.tools.ant.taskdefs.Java").getClass());
			project.addTaskDefinition("tstamp",createObject("java","org.apache.tools.ant.taskdefs.Tstamp").getClass());
			project.addTaskDefinition("taskdef",createObject("java","org.apache.tools.ant.taskdefs.Taskdef").getClass());
 */
// thread = createObject("java","java.lang.Thread");
// project.setCoreLoader(Thread.currentThread().getContextClassLoader());
//			project.setCoreLoader(this.getClass().getClassLoader());
//        project.setCoreLoader( this.getClass().getClassLoader() );

			project.setBasedir(baseDir);
			if(structKeyExists(attributes,"properties")) {
				for(x=1; x lte listLen(structKeyList(attributes.properties)); x++){
					prop = listGetAt(structKeyList(attributes.properties),x);
					project.setProperty(prop,attributes.properties[prop]);
				}
			}

			helper = projectHelper.getProjectHelper();

			project.setProjectReference(helper);
			if(NOT fileExists(buildFile)){
				throwerror("antrunner.noBuildFileDude","File not found, dude:" & buildFile);
			}

			helper.configureProject(project, createObject("java","java.io.File").init(buildFile));
			//helper.parse(project,createObject("java","java.io.File").init(buildFile));

			if(targetName == ""){
				targetName = project.getDefaultTarget();
			}

			if(targetName == ""){
				writeOutput("Target Not found : " & targetName);
			}

			runLogger.setErrorPrintStream(errPrint);
			runLogger.setOutputPrintStream(outPrint);
			runLogger.setMessageOutputLevel(project[attributes.logLevel]);
			//runLogger.setMessageOutputLevel(project.MSG_VERBOSE);
			project.addBuildListener(runLogger);
			project.executeTarget(targetName);
			runResults.errorText = errStream.toString();
			runResults.outText = outStream.toString();
			caller[attributes.resultsVar] = runResults;
		</cfscript>

			<cfif not variables.hasEndTag>
				<cfset onEndTag(attributes,caller,"") />
			</cfif>
	    <cfreturn variables.hasEndTag>
	</cffunction>

    <cffunction name="onEndTag" output="yes" returntype="boolean">
   		<cfargument name="attributes" type="struct">
   		<cfargument name="caller" type="struct">
  		<cfargument name="generatedContent" type="string">
		<cfreturn false/>
	</cffunction>

  <cffunction name="setRailoLoaderClassPath" output="false" returntype="any" access="private">
		<cfscript>
			var jarsArry = getPageContext().getConfig().getClassLoader().getURLs();
			var system = CreateObject("java", "java.lang.System");
			var classpath = system.getProperty("java.class.path");
			var delim = system.getProperty("path.separator");
			for(x = 1; x lte arrayLen(jarsArry); x++) {
				jarpath = replace(jarsArry[x].toString(),"file:","");
				classpath = listAppend(classpath,jarpath,delim);
			}
			system.setProperty("java.class.path",classpath)
		</cfscript>
		<cfreturn classpath />
	</cffunction>


		<cffunction name="addTaskByName" output="false" hint="adds a task definition by name">
			<cfargument name="project" required="true" />
			<cfargument name="taskNames" default="" />
			<cfscript>
					var propertiesFile = project.class.getResourceAsStream("/org/apache/tools/ant/taskdefs/defaults.properties");
					var props = createObject("java","java.util.Properties");
					var x = 0;
					var taskName = "";
					var propElements = "";
					props.load(propertiesFile);
					propElements = props.propertyNames();
					while(propElements.hasMoreElements()){
						taskName = propElements.nextElement();
						try{
				 			project.addTaskDefinition(taskName,createObject("java",props.getProperty(taskName)).getClass());
						} catch (any ex) {
							//
						}
					}
		// 			project.addTaskDefinition("org.apache.tools.ant.Task",createObject("java","org.apache.tools.ant.Task").getClass());
			</cfscript>
		</cffunction>

		<cffunction name="addTaskDef" output="false" hint="adds a task definition by class">
			<cfargument name="taskDefs" default="" />
			<cfscript>
					for(x = 1; x lte structKeyList(taskDefs); x++) {
			 			project.addTaskDefinition(props[x],createObject("java","org.apache.tools.ant.taskdefs.Delete").getClass());
					}
			</cfscript>
		</cffunction>

		<cffunction name="throwerror" access="private" output="false">
			<cfargument name="type" required="true" />
			<cfargument name="message" required="true" />
			<cfargument name="detail" default="#arguments.message#" />
			<cfthrow type="#arguments.type#" message="#arguments.message#" detail="#arguments.detail#" />
		</cffunction>

</cfcomponent>