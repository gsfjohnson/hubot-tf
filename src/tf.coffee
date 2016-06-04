# Description:
#   Manage TF with Hubot.
#
# Dependencies:
#   "sys": ">= 0.0.0"
#
# Configuration:
#   None
#
# Commands:
#   hubot tf help - list commands
#
# Author:
#   gsfjohnson

fs = require('fs')
sys = require('sys')
exec = require('child_process').exec

basepath = process.env.HUBOT_TF_BASEPATH || ''
privatekey = basepath + "/hubot-tf.key"
publickey = privatekey + ".pub"
tfName = tfRole = 'tf'

sendqueue = []
servicequeue = ->
  o = sendqueue.shift()
  msg = o['msg']
  out = o['out']
  msg.send {room: msg.message.user.name}, out

isAuthorized = (robot, msg) ->
  u = msg.envelope.user
  return true if robot.auth.isAdmin(u) or robot.auth.hasRole(u,tfRole)
  msg.send {room: u.name}, "Not authorized.  Missing `#{tfRole}` role."
  return false

fileExistsSendAndReturnTrue = (msg, file, failresponse) ->
  if fs.existsSync "#{basepath}/#{file}"
    msg.send {room: msg.message.user.name}, failresponse
    return true
  return false  # does not exist

fileMissingSendAndReturnTrue = (msg, file, failresponse) ->
  if ! fs.existsSync "#{basepath}/#{file}"
    msg.send {room: msg.message.user.name}, failresponse
    return true
  return false  # file exists

execAndSendOutput = (msg, cmd) ->
  exec cmd, (error, stdout, stderr) ->
    if stderr
      msg.send {room: msg.message.user.name}, "stderr:\n```\n#{stderr}\n```"
    else if error
      msg.send {room: msg.message.user.name}, "Error: #{error}"
    if stdout
      msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"

getDirectories = ->
  dirs = []
  for fn in fs.readdirSync(basepath)
    stat = fs.statSync("#{basepath}/#{fn}")
    dirs.push fn if stat.isDirectory()
  return dirs

formatProjEnv = (robot, proj) ->
  brainloc = "hubot-tf_env_#{proj}"
  localstorage = JSON.parse(robot.brain.get brainloc) or {}

  ekvs = [ "`#{proj}` env:" ]
  ekvs.push "  `#{k}` = `#{v}`" for k,v of localstorage
  ekvs = [ "No environment variables for `#{proj}`." ] unless ekvs.length > 1
  return ekvs.join "\n"

updateProjEnv = (robot, proj, key, val=false) ->
  brainloc = "hubot-tf_env_#{proj}"
  localstorage = JSON.parse(robot.brain.get brainloc) or {}
  console.log "loaded #{brainloc}: #{JSON.stringify(localstorage)}"
  if val is false
    delete localstorage[key]
    out = "env `#{proj}`: `#{key}` unset."
  else
    localstorage[key] = val
    out = "env `#{proj}`: `#{key}` = `#{val}`"
  robot.brain.set brainloc, JSON.stringify(localstorage)
  robot.brain.save()
  console.log "saved #{brainloc}: #{JSON.stringify(localstorage)}"
  return out

getProjEnv = (robot, proj) ->
  brainloc = "hubot-tf_env_#{proj}"
  localstorage = JSON.parse(robot.brain.get brainloc) or {}
  ekva = []
  ekva.push "#{k}=#{v}" for k,v of localstorage
  return ekva.join " "

module.exports = (robot) ->

  robot.respond /tf help$/, (msg) ->
    cmds = []
    arr = [
      "#{tfName} create key - create rsa key for git"
      "#{tfName} display key - display public key for github deploy"
      "#{tfName} erase key - delete rsa key"
      "#{tfName} list - enumerate projects"
      "#{tfName} delete <projectname> - erase project"
      "#{tfName} git clone <repourl> <proj> - clone git repo into proj directory"
      "#{tfName} git pull <proj> - git pull"
      "#{tfName} git remote <proj> - git remote info"
      "#{tfName} tf apply <proj> [verbose] - create resources"
      "#{tfName} tf destroy <proj> [verbose] - destroy resources"
      "#{tfName} tf get <proj> [update] - get modules, specify update if needed"
      "#{tfName} tf plan <proj> [verbose] - show plan"
      "#{tfName} tf refresh <proj> [verbose] - refresh resource state"
      "#{tfName} env <proj>|me|all <key>=<value>[ key=value] - set env"
      "#{tfName} env <proj>|me|all <key> - unset env var"
      "#{tfName} env [proj] - show env"
    ]

    for str in arr
      cmd = str.split " - "
      cmds.push "`#{cmd[0]}` - #{cmd[1]}"

    if msg.message?.user?.name?
      robot.send {room: msg.message?.user?.name}, cmds.join "\n"
    else
      msg.reply cmds.join "\n"


  robot.respond /tf create key$/i, (msg) ->
    return unless isAuthorized robot, msg
    return if fileExistsSendAndReturnTrue msg, publickey, "Key exists!  Erase it first."

    exec "ssh-keygen -f #{privatekey} -b 1024 -C hubot-tf -N ''", (error, stdout, stderr) ->
      #msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"
      pubkey = fs.readFileSync("#{publickey}", 'utf-8').toString()
      msg.send {room: msg.message.user.name}, "Add this to your github repo as a deploy key, to give hubot read-only access.\n```\n#{pubkey}\n```"


  robot.respond /tf display key$/i, (msg) ->
    return unless isAuthorized robot, msg
    return if fileMissingSendAndReturnTrue msg, publickey, "No key on file!  Create one first."

    pubkey = fs.readFileSync("#{publickey}", 'utf-8').toString()
    return msg.send {room: msg.message.user.name}, "Add this to your github repo as a deploy key, to give hubot read-only access.\n```\n#{pubkey}\n```"


  robot.respond /tf erase key$/i, (msg) ->
    return unless isAuthorized robot, msg
    return if fileMissingSendAndReturnTrue msg, publickey, "No key on file!  Create one first."

    fs.unlinkSync("#{privatekey}")
    fs.unlinkSync("#{publickey}")
    return msg.send {room: msg.message.user.name}, "Key erased!"


  robot.respond /tf git clone ([^\s]+) ([^\s]+)$/i, (msg) ->
    return unless isAuthorized robot, msg

    url = msg.match[1]
    proj = msg.match[2].replace /\//, "_"
    projpath = basepath + "/" + proj

    #fn = msg.message.user.name
    #fn.replace /\//, "_"
    fp = basepath + "/hubot-tf"

    cmd = "GIT_SSH_COMMAND='ssh -i #{privatekey} -F /dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' git clone #{url} #{projpath}"
    execAndSendOutput msg, cmd


  robot.respond /tf list$/i, (msg) ->
    return unless isAuthorized robot, msg

    dirs = getDirectories()

    if dirs.length > 0
      return msg.send {room: msg.message.user.name}, "Projects: `#{dirs.join '`, `'}`"

    return msg.send {room: msg.message.user.name}, "No projects.  Clone something with `tf git clone <repourl> <proj>`."


  robot.respond /tf git (remote|pull) ([^\s]+)$/i, (msg) ->
    action = msg.match[1]
    proj = msg.match[2].replace /\//, "_"
    return unless isAuthorized robot, msg
    return if fileMissingSendAndReturnTrue msg, proj, "Invalid project name: `#{proj}`"

    gitcmd = "git remote -v" if action == 'remote'
    gitcmd = "git pull" if action == 'pull'
    cmd = "cd #{basepath}/#{proj} ; #{gitcmd}"
    execAndSendOutput msg, cmd


  robot.respond /tf tf (get) ([^\s]+)( update)?$/i, (msg) ->
    action = msg.match[1]
    proj = msg.match[2].replace /\//, "_"
    update = if msg.match[3] then true else false
    return unless isAuthorized robot, msg
    return if fileMissingSendAndReturnTrue msg, proj, "Invalid project name: `#{proj}`"

    params = [ "-no-color" ]
    params.push "-update=true" if update
    paramline = params.join " "

    cmd = "cd #{basepath}/#{proj}; terraform #{action} #{paramline}"
    execAndSendOutput msg, cmd


  robot.respond /tf delete ([^\s]+)$/i, (msg) ->
    proj = msg.match[1].replace /\//, "_"
    return unless isAuthorized robot, msg
    return if fileMissingSendAndReturnTrue msg, proj, "Invalid project name: `#{proj}`"

    return exec "cd #{basepath}; rm -rf #{proj}", (error, stdout, stderr) ->
      msg.send {room: msg.message.user.name}, "Project deleted: #{proj}"


  robot.respond /tf tf (plan|refresh|apply|destroy) ([^\s]+)( verbose)?$/i, (msg) ->
    action = msg.match[1]
    proj = msg.match[2].replace /\//, "_"
    verbose = true if msg.match[3]
    return unless isAuthorized robot, msg
    return if fileMissingSendAndReturnTrue msg, proj, "Invalid project name: `#{proj}`"

    env = []
    for domain in ['all','me',proj]
      domain = msg.message.user.name if domain is 'me'
      env.push getProjEnv robot, domain
    envline = env.join " "

    params = []
    params.push "-input=false"
    params.push "-no-color"
    paramline = params.join " "

    cmdline = "cd #{basepath}/#{proj}; #{envline} terraform #{action} #{paramline}"
    cmdline = "#{cmdline} -force" if action == 'destroy'
    msg.send {room: msg.message.user.name}, "```\n#{cmdline}\n```"
    exec cmdline, (error, stdout, stderr) ->
      if stdout and !stderr
        if stdout.length < 2048
          return msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"
        else unless verbose
          out = 'Error'
          for line in stdout.split "\n"
            if line.match /^(?:Plan: |Apply complete)/
              out = line
          return msg.send {room: msg.message.user.name}, "```\n#{out}\n```"
        out = []
        waitms = 333
        textchunk = ''
        for line in stdout.split "\n"
          if line.match /^(?:\+\s|Plan: )/
            textchunk = out.join "\n"
            sendqueue.push { msg: msg, out: "```\n#{textchunk}\n```" }
            setTimeout servicequeue, waitms
            waitms = waitms + 333
            out = []
          out.push line
        textchunk = out.join "\n"
        sendqueue.push { msg: msg, out: "```\n#{textchunk}\n```" }
        setTimeout servicequeue, waitms
      if stderr
        msg.send {room: msg.message.user.name}, "stderr:\n```\n#{stderr}\n```"
      else if error
        msg.send {room: msg.message.user.name}, "error:\n```\n#{error}\n```"


  robot.respond /tf env ([^\s]+) (.+)$/i, (msg) ->
    console.log "tf env-set"
    proj = msg.match[1].replace /\//, "_"
    ekvpairs = msg.match[2].split " "

    return unless isAuthorized robot, msg
    if proj not in ['me','all']
      return if fileMissingSendAndReturnTrue msg, proj, "Env-set: invalid project name: `#{proj}`"

    proj = msg.message.user.name if proj is 'me'

    outs = []
    for ekv in ekvpairs
      ekva = ekv.split "="
      out = updateProjEnv robot, proj, ekva[0], ekva[1]
      outs.push out

    return msg.send {room: msg.message.user.name}, outs.join "\n"


  robot.respond /tf env(?: ([^\s]+))?$/i, (msg) ->
    console.log "tf env-show"
    proj = if msg.match[1] then msg.match[1].replace /\//, "_" else false

    return unless isAuthorized robot, msg
    if proj and proj not in ['me','all']
      return if fileMissingSendAndReturnTrue msg, proj, "Env-show: invalid project name: `#{proj}`"

    domains = if proj then [proj] else ['all','me']

    out = []
    for proj in domains
      proj = msg.message.user.name if proj is 'me'
      out.push formatProjEnv robot, proj

    return msg.send {room: msg.message.user.name}, out.join "\n"
