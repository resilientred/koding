option '-d', '--database [DB]', 'specify the db to connect to [local|vpn|wan]'
option '-D', '--debug', 'runs with node --debug'
option '-P', '--pistachios', "as a post-processing step, it compiles any pistachios inline"
option '-c', '--configFile [CONFIG]', 'What config file to use.'

ProgressBar = require './builders/node_modules/progress'
Builder     = require './builders/Builder'
S3          = require './builders/s3'
log4js      = require "./builders/node_modules/log4js"
log         = log4js.getLogger("[Cakefile]")
prompt      = require './builders/node_modules/prompt'
hat         = require "./builders/node_modules/hat"
mkdirp      = require './builders/node_modules/mkdirp'
sourceCodeAnalyzer = new (require "./builders/SourceCodeAnalyzer.coffee")
processes   = require "processes"
{spawn, exec} = require 'child_process'
fs            = require "fs"
nodePath      = require 'path'

KODING_CAKE = './node_modules/koding-cake/bin/cake'

# log = 
#   info  : console.log
#   debug : console.log
#   warn  : console.log

 
# create required folders
mkdirp.sync "./.build/.cache"
mkdirp.sync "./website_nonstatic"
fs.writeFileSync "./.revision","0.0.1"

# get current version

if process.argv[2] is 'buildForProduction'
  rev = ((fs.readFileSync ".revision").toString().replace("\n","")).split(".")
  rev[2]++
  version = rev.join(".")
else
  version = (fs.readFileSync ".revision").toString().replace("\r","").replace("\n","")

clientFileMiddleware  = (options, code, callback)->
  console.log 'args', options
  # here you can change the content of kd.js before it's written to it's final file.
  # options is the cakefile options, opt is where file is passed in.
  {libraries,kdjs} = code
      
  compressJs = (js,callback)->
    totalTicks = 200
    bar = new ProgressBar 'Closure compiling kd.js [:bar] :percent :elapseds',{total: 200,width:50,incomplete:" "}
    ticks = 0
    a = setInterval ->
      bar.tick()
      ticks++
    ,500

    tmpFile = "./.build/#{hat()}.txt"
    tmpFileCompiled = tmpFile+".js"
    fs.writeFile tmpFile,js,(err)-> 
      execStr = "java -jar #{options.closureCompilerPath} --js #{tmpFile} --js_output_file #{tmpFileCompiled}"
      console.log execStr
      exec execStr,(err,stdout,stderr)->
        if stderr
          unless arguments[2].indexOf "\n0 error(s)"
            log.error arguments
            log.error "CLOSURE FAILED TO COMPILE KD.JS CHECK THE ERROR MSG ABOVE. EXITING."
            process.exit()
          else
            # log.debug "closure compile finished successfully."
        else if stdout
          console.log "12",arguments
        else throw err
        bar.tick() for ko in [ticks...totalTicks]
        fs.readFile tmpFileCompiled,'utf8',(err,data)->
          clearInterval a
          unless err
            callback null,data
            # fs.unlink tmpFileCompiled,->
            # fs.unlink tmpFile,->
          else
            log.error "something wrong with compressing #{tmpFile}",execStr
            callback err

  kdjs =  "var KD = {};\n" +
          "KD.config = "+JSON.stringify(options.runtimeOptions)+";\n"+
          kdjs
  
  # return callback null,kdjs+libraries
  unless options.uglify
    callback null,(libraries+kdjs)
  else
    compressJs (libraries+kdjs),(err,data)->
      unless err
        callback null,data         
      else
        throw err

pipeStd =(children...)->
  for child in children
    child.stdout.pipe process.stdout
    child.stderr.pipe process.stderr

normalizeConfigPath =(path)->
  path ?= './config/dev'
  nodePath.join __dirname, path

buildClient =(configFile, callback=->)->
  try
    config = require configFile
  catch e
    console.log 'hello', e
  builder = new Builder config.client, clientFileMiddleware, ""
  builder.watcher.initialize()
  builder.watcher.on 'initDidComplete', ->
    builder.buildClient "", ->
      builder.buildCss "", ->
        builder.buildIndex "", ->
          callback null

task 'buildClient', (options)->
  configFile = normalizeConfigPath options.configFile
  buildClient configFile

task 'configureRabbitMq',->
  exec 'which rabbitmq-server',(a,stdout,c)->
    if stdout is ''
      console.log "Please install RabbitMQ. (do e.g. brew install rabbitmq)"
    else
      exec 'rabbitmq-plugins enable rabbitmq_tracing',(a,b,c)->
        console.log a,b,c
        exec 'rabbitmq-plugins enable rabbitmq_management_visualiser',(a,b,c)->
          console.log """
            I will TRY to download and install https://github.com/downloads/tonyg/presence-exchange/rabbit_presence_exchange-20120411.01.ez
            you should find the path where rabbitmq plugins are installed, on mac after brew install;
            /usr/local/Cellar/rabbitmq/2.7.1/lib/rabbitmq/erlang/lib/rabbitmq-2.7.1/plugins
            it is here. look at the output below, it might be somehwere there..
            OK TRYING... if that doesn't work, find the path, ping chris on skype :)
            """
          exec 'rabbitmq-plugins --invalidOption',(a,b,c)->
            d = c.split "\n"
            for line in d
              if line.indexOf("/plugins") > 0
                e = line 
                break
            e = e.trim().replace /"|]|,/g,""
            rabbitMqPluginPath = e
            exec "wget -O #{rabbitMqPluginPath}/rabbit_presence_exchange.ez https://github.com/downloads/tonyg/presence-exchange/rabbit_presence_exchange-20120411.01.ez",(a,b,c)->
              exec 'rabbitmq-plugins enable rabbit_presence_exchange',(a,b,c)-> 
                console.log a,b,c
                exec 'rabbitmqctl stop',->
                  console.log "ALL DONE. (hopefully) - start RabbitMQ server, run: rabbitmq-server (to detach: -detached)"

task 'run', (options)->
  configFile = normalizeConfigPath options.configFile
  console.log 'KONFIG', configFile
  broker = spawn './broker/start.sh'
  serverSupervisor = spawn KODING_CAKE, [
    './server',
    '-c', configFile
    'run'
  ]
  socialSupervisor = spawn KODING_CAKE, [
    './workers/social'
    '-c', configFile
    '-n', 10
    'run'
  ]
  pipeStd(
    broker
    serverSupervisor
    socialSupervisor
  )
  setInterval (->),10000


  # broker = spawn './broker/start.sh'
  # server = spawn 'node', ['server/index.js', '-c', './config.coffee']
  # social = spawn 'node', ['workers/social/index.js', '-d', options.database or 'mongohq-dev']
  # logPath = options.logPath ? '/tmp'  
  # procs = {broker, server, social}
  # if options.runClient
  #   client = spawn 'cake', ['build']
  #   procs.push client
  # for own name, proc of procs
  #   logFile = fs.createWriteStream("#{logPath}/#{name}.log", flags:'a')
  #   proc.stdout.pipe(logFile)
  #   proc.stderr.pipe(logFile)


task 'buildAll',"build chris's modules", ->

  buildables = ["processes","pistachio","scrubber","sinkrow","mongoop","koding-dnode-protocol","jspath","bongo-client"]
  # log.info "building..."
  b = (next) ->
    cmd = "cd ./node_modules/#{buildables[next]} && cake build"
    log.info "building... cmd: #{cmd}"
    processes.run 
      cmd     : cmd
      log     : yes       # or provide a path for log file
      restart : no        # or provide a function
      onExit  : (id)->
        # log.debug "pid.#{id} said: 'im done.'[#{cmd}]"
        if next is buildables.length-1
          log.info "build complete. now running cake build."
          # process.exit()
          invoke "build"
        else
          b next+1
  b 0



task 'buildForProduction','set correct flags, and get ready to run in production servers.',(options)->
  
  options.port      = 3000
  options.host      = "localhost"
  options.database  = "beta" 
  options.port      = "3000"
  options.dontStart = yes
  options.uglify    = yes
  options.useStatic = yes

  prompt.start()
  prompt.get [{message:"I will build revision:#{version} is this ok? (yes/no)",name:'p'}],  (err, result) ->
    
    if result.p is "yes"
      log.debug 'version',version
      fs.writeFileSync "./.revision",version
      invoke 'build'
      console.log "YOU HAVE 10 SECONDS TO DO CTRL-C. CURRENT REV:#{version}"
    else
      process.exit()



task 'install', 'install all modules in CakeNodeModules.coffee, get ready for build',(options)->
  l = (d) -> log.info d.replace /\n+$/, ''
  {our_modules, npm_modules} = require "./CakeNodeModules"
  reqs = npm_modules
  exe = ("npm i "+name+"@"+ver for name,ver of reqs).join ";\n"
  a = exec exe,->
  a.stdout.on 'data', l
  a.stderr.on 'data', l

task 'uninstall', 'uninstall all modules listed in CakeNodeModules.coffee',(options)->
  l = (d) -> log.info d.replace /\n+$/, ''
  {our_modules, npm_modules} = require "./CakeNodeModules"
  reqs = npm_modules
  exe = "npm uninstall "+(name for name,ver of reqs).join " "
  a = exec exe,->
  a.stdout.on 'data', l
  a.stderr.on 'data', l

task 'checkModules', 'check node_modules dir',(options)->  
  {our_modules, npm_modules} = require "./CakeNodeModules"
  required_versions = npm_modules
  npm_modules = (name for name,ver of npm_modules)  
  gitIgnore = ((fs.readFileSync "./.gitignore").toString().replace(/\r\n/g,"\n").split "\n")

  data = fs.readdirSync "./node_modules"
  untracked_mods = (mod for mod in data when mod not in our_modules and mod not in npm_modules and "/node_modules/#{mod}" not in gitIgnore)    
  if untracked_mods.length > 0      
    console.log "[ERROR] UNTRACKED MODULES FOUND:",untracked_mods
    console.log "Untracked modules detected add each either to CakeNodeModules.coffee, and/or to .gitignore (exactly as: e.g. /node_modules/#{untracked_mods[0]}). Exiting."
    process.exit()

  unignored_mods = (mod for mod in data when mod not in our_modules and "/node_modules/#{mod}" not in gitIgnore)
  if unignored_mods.length > 0      
    console.log "[ERROR] UN-IGNORED NPM MODULES FOUND:",unignored_mods
    console.log "Don't do git-add before adding them to .gitignore (exactly as: e.g. /node_modules/#{unignored_mods[0]}). Exiting."
    process.exit()

  # check if versions match
  for mod,ver of required_versions when (packageVersion = (JSON.parse(fs.readFileSync "./node_modules/#{mod}/package.json")).version) isnt required_versions[mod]
    log.error "[ERROR] NPM MODULE VERSION MISMATCH: #{mod} version is incorrect:#{packageVersion}. it has to be #{ver}."
    log.info  "If you want to keep this version edit CakeNodeModules.coffee or run: npm install #{mod}@#{ver}"
    process.exit()

  all_mods = npm_modules.concat our_modules
  uninstalled_mods = (mod for mod in all_mods when mod not in data)
  if uninstalled_mods.length > 0      
    console.log "[ERROR] UNINSTALLED MODULES FOUND:",uninstalled_mods
    console.log "Please run: npm install #{uninstalled_mods.join(" ")} (or cake install)"
    console.log "Exiting."
    process.exit()
  else
    console.log "./node_modules check complete."



task 'writeGitIgnore','updates a part of .gitignore file to avoid conflicts in ./node_modules',(options)->
  
  fs.readFile "./.gitignore",'utf8',(err,data)->
    arr = data.split "\n"

task 'build', 'optimized version for deployment', (options)->  
  # invoke 'checkModules'
  # # require './server/dependencies.coffee' # check if you have all npm libs to run kfmjs
  # options.port      or= 3000
  # options.host      or= "localhost"
  # options.watch     or= 1000
  # options.database  ?= "mongohq-dev" 
  # options.port      ?= "3000"
  # options.dontStart ?= no
  # options.uglify    ?= no
  

  # options.target = targetPaths.server ? "/tmp/kd-server.js" 
  
  # {dontStart,uglify,database} = options
  # build options
  
  
  
  
  

# ------------- BUILDER START ----------#
build = (options)->
  log.debug "building with following options, ctrl-c before too late:",options
  debug = if options.debug? then "--debug --prof --prof-lazy" else "--stack_size=2048"
  run = 
    command: ["node", [debug,options.target, process.cwd(), options.database, options.port, options.cron, options.host]]

  builder = new Builder options,targetPaths,"",run
  
  sourceCodeAnalyzer.attachListeners builder if options.sourceCodeAnalyze
  
  builder.watcher.initialize()

  # EVENTS -

  issueFrontendReloadCommand = ()->
    if options.autoReload
      fs.writeFile "./website/js/requiresReload.txt","#{Date.now()}",'utf8',()->
        log.info "reload command is issued to frontend"
    else
      fs.writeFile "./website/js/requiresReload.txt","0",'utf8',()->
        log.info "Auto reload is not on. Use cake -r to enable."


  builder.watcher.on "initDidComplete",(changes)->
    builder.buildServer "",()->
      unless options.dontStart
        builder.processMonitor.flags.forever = yes
        builder.processMonitor.startProcess()
      builder.buildClient "",()->
        builder.buildCss "",()->
          builder.buildIndex "",()->
            unless options.dontStart
              log.info "website is ready at #{options.host}:#{options.port}"
              builder.watcher.start 1000
              # builder.buildApplications targetPaths.installedApps, targetPaths.apps
              # issueFrontendReloadCommand()
            else
              if options.dontStart                    
                targetPaths.prodPostBuildSteps options,->
                  log.info "build complete, now run: monit start kfmjs or"
                  log.info "export NODE_PATH=#{process.cwd()}/node_modules/ && node #{run.command[1].join ' '}"
              else
                log.info "build complete, now run:","node #{run.command[1].join ' '}"
      
  builder.watcher.on "changeDidHappen",(changes)-> 
    # log.info changes
    if changes.Client? and not changes.StylusFiles
      builder.buildClient "",()->
        builder.buildIndex "",()->
          # log.debug "client build is complete"
      
    if changes.Server?# or changes.Models? -- Don't we need to follow Model files for changes?
      builder.buildServer "",()-> 
      builder.processMonitor.restartProcess() unless options.dontStart
    if changes.Client?.StylusFiles? 
      builder.buildCss "", ->
        builder.buildIndex "", ->
    if changes.Cake                                  
      log.debug "Cakefile changed.."
      builder.watcher.reInitialize()

    issueFrontendReloadCommand()

  

  builder.processMonitor.on "processDidExit",(code)->

  builder.watcher.on "CoffeeScript Compile Error",(filePath,error)->
    log.error "CoffeeScript ERROR, last good known version of #{filePath} is compiled. Please fix this error and recompile. #{error}"
    spawn.apply null, ["say",["coffee script error"]]
      # builder.resetWatcher()
      # builder.watcher.initialize()

# ------------- BUILDER END ----------#























# ------------ OTHER LESS IMPORTANT STUFF ---------------------#

task 'deploy','',(options)->

  fs.readFile "./.revision","utf8",(err,data)->
    throw err if err
    rev = data.replace "\n",""
    filename = "kfmjs-#{rev}.tar.gz"    
    execStr = "cd .. && /usr/bin/tar -czf #{filename} --exclude 'kites/*' --exclude '.git/*' kfmjs"
    log.info "executing #{execStr}"
    exec execStr,(err,stdout,stderr)->
      s3 = new S3 
        key     : "AKIAJO74E23N33AFRGAQ"
        secret  : "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"
        bucket  : "koding-updater"
      log.info "starting to upload to s3"
      s3.putFile "../#{filename}",filename,(err,res)->
        console.log err,res      
        foo = exec "./build/install_sl_vm/install.py --hourly --cores 1 --ram 1 --port 10 --bandwidth 1000 --fqdn web1.prod.system.koding.com",(err,stdout,stderr)->
          # console.log arguments
          depStr = "./build/install_ec2/install_ec2.py --fqdn web#{Date.now()}.beta.system.aws.koding.com --int --kfmjs #{rev} "
          log.info "deploying #{depStr}"
          foo = exec depStr,(err,stdout,stderr)->
            console.log "deployment complete."
        foo.stdout.on 'data', (data)-> log.info "#{data}".replace /\n+$/, ''      
        foo.stderr.on 'data', (data)-> log.info "#{data}".replace /\n+$/, ''  

task 'parseAnalyzedCss','',(options)->

  fs.readFile "/tmp/identicals.css",'utf8',(err,data)->
    stuff = JSON.parse data
    
    log.info stuff

task 'analyzeCss','',(options)->
  configFile = normalizeConfigPath options.configFile
  config = require configFile
  compareArrays = (arrA, arrB) ->
    return false if arrA?.length isnt arrB?.length
    if arrA?.slice()?.sort?
      cA = arrA.slice().sort().join("")
      cB = arrB.slice().sort().join("")
      cA is cB    
    else
      # log.error "something wrong with this pair of arrays",arrA,arrB
    


  fs.readFile config.client.css,'utf8',(err,data)->
    br = 'body,html'+(data.split "body,html")[1]
    # log.debug arr
    arr = br.split "\n"
    css = {}
    for own line in arr
      ln = line.split "{"
      ln1 = ln[1]?.substr 0,ln[1].length-1
      css[ln[0]] = ln1?.split ";"
      # unless ln1? then log.error line
    log.info "getting in"
    # fs.writeFileSync "/tmp/f.css", JSON.stringify css,"utf8"
    # log.info "written."
    identicals = {}
    counter=
      chars : 0
      fns   : 0
    for own name,selector of css
      for own name2,selector2 of css
        fl = firstLetter = name.substr(0,1)
        unless fl is "@" or fl is " " or fl is "{" or fl is "}"
          res = compareArrays selector2,selector
          if res and name isnt name2
            unless identicals[name2]?[name]?
              # log.info fl
              log.info "#{name} --------- is identical to -----------> #{name2}"
              identicals[name] ?= {}
              identicals[name][name2] = 1
              identicals[name].__content = selector
              counter.chars+=selector.join(";").length
              counter.fns++
          # log.debug selector,selector2  
    fs.writeFileSync "/tmp/identicals.css", JSON.stringify identicals,"utf8"    
    log.info "------------------"
    log.info "log file is at /tmp/identicals.css"
    log.info "#{counter.fns} selectors contain identical CSS properties"
    log.info "possible savings:",Math.floor(counter.chars/1024)+" kbytes"
    log.info "this tool works only if u did 'cake -usd vpn beta' before running analyzeCss."

task 'uploadToS3','',(options)->
  S3 = new require("./build/s3")
  s3 = new S3
    key     : "AKIAJO74E23N33AFRGAQ"
    secret  : "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"
    bucket  : "koding"

  s3.putFile targetPaths.client,"js/kd.js",()->
  s3.putFile targetPaths.css,"css/kd.css",()->
  s3.putFile targetPaths.index,"index.html",()->
