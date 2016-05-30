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
exec = require('child_process').exec;

basepath = process.env.HUBOT_TF_BASEPATH || ''
privatekey = basepath + "/hubot-tf.key"
publickey = privatekey + ".pub"
tfName = tfRole = 'tf'

sendqueue = []
servicequeue = ->
  obj = sendqueue.shift()
  console.log JSON.stringify obj
  obj['msg'].send {room: obj['msg'].message.user.name}, obj['out']

module.exports = (robot) ->

  robot.respond /tf help$/, (msg) ->
    cmds = []
    arr = [
      "#{tfName} (create|show|destroy) key - rsa key operations, for git"
      "#{tfName} clone <repourl> <projectname> - clone git repo into projectname directory"
      "#{tfName} list projects - enumerate projects"
      "#{tfName} delete <projectname> - erase <projectname> files"
      "#{tfName} (plan|refresh|apply|get|destroy) <projectname> - tf operations"
      "#{tfName} env <projectname> set <key>=<value> - set env var"
      "#{tfName} env <projectname> unset <key> - unset environmental variable"
      "#{tfName} env <projectname> list - show env for project"
    ]

    for str in arr
      cmd = str.split " - "
      cmds.push "`#{cmd[0]}` - #{cmd[1]}"

    if msg.message?.user?.name?
      robot.send {room: msg.message?.user?.name}, cmds.join "\n"
    else
      msg.reply cmds.join "\n"

  robot.respond /tf create key$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    if fs.existsSync("#{publickey}")
      return msg.send {room: msg.message.user.name}, "Key exists!  Destroy it first."

    exec "ssh-keygen -f #{privatekey} -b 1024 -C hubot-tf -N ''", (error, stdout, stderr) ->
      #msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"
      pubkey = fs.readFileSync("#{publickey}", 'utf-8').toString()
      msg.send {room: msg.message.user.name}, "```\n#{pubkey}\n```"

  robot.respond /tf show key$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    if ! fs.existsSync("#{publickey}")
      return msg.send {room: msg.message.user.name}, "No key on file!  Create one first."

    pubkey = fs.readFileSync("#{publickey}", 'utf-8').toString()
    return msg.send {room: msg.message.user.name}, "```\n#{pubkey}\n```"

  robot.respond /tf destroy key$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    if ! fs.existsSync("#{publickey}")
      return msg.send {room: msg.message.user.name}, "No key on file!  Create one first."

    fs.unlinkSync("#{privatekey}")
    fs.unlinkSync("#{publickey}")
    return msg.send {room: msg.message.user.name}, "Key destroyed!"

  robot.respond /tf clone ([^\s]+) ([^\s]+)$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    url = msg.match[1]
    projname = msg.match[2].replace /\//, "_"
    projpath = basepath + "/" + projname

    #fn = msg.message.user.name
    #fn.replace /\//, "_"
    fp = basepath + "/hubot-tf"

    exec "GIT_SSH_COMMAND='ssh -i #{privatekey} -F /dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' git clone #{url} #{projpath}", (error, stdout, stderr) ->
      if stderr
        msg.send {room: msg.message.user.name}, "stderr:\n```\n#{stderr}\n```"
      else if error
        msg.send {room: msg.message.user.name}, "Error: #{error}"
      if stdout
        msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"

  robot.respond /tf list(\sprojects)?$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    dir = []
    for fn in fs.readdirSync(basepath)
      stat = fs.statSync("#{basepath}/#{fn}")
      dir.push fn if stat.isDirectory()

    return msg.send {room: msg.message.user.name}, dir.join "\n"

  robot.respond /tf (get) ([^\s]+)$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    action = msg.match[1]
    projname = msg.match[2].replace /\//, "_"

    unless fs.existsSync("#{basepath}/#{projname}")
      return msg.send {room: msg.message.user.name}, "Invalid project name: `#{projname}`"

    exec "cd #{basepath}/#{projname}; terraform #{action} -no-color", (error, stdout, stderr) ->
      if stderr
        msg.send {room: msg.message.user.name}, "stderr:\n```\n#{stderr}\n```"
      else if error
        msg.send {room: msg.message.user.name}, "error:\n```\n#{error}\n```"
      if stdout
        msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"

  robot.respond /tf delete ([^\s]+)$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    projname = msg.match[1].replace /\//, "_"

    unless fs.existsSync("#{basepath}/#{projname}")
      return msg.send {room: msg.message.user.name}, "Invalid project name: `#{projname}`"

    return exec "cd #{basepath}; rm -rf #{projname}", (error, stdout, stderr) ->
      msg.send {room: msg.message.user.name}, "Project deleted: #{projname}"

  robot.respond /tf (plan|refresh|apply|destroy) ([^\s]+)( verbose)?$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    action = msg.match[1]
    projname = msg.match[2].replace /\//, "_"
    verbose = true if msg.match[3]

    unless fs.existsSync("#{basepath}/#{projname}")
      return msg.send {room: msg.message.user.name}, "Invalid project name: `#{projname}`"

    brainloc = "hubot-tf_#{projname}"
    localstorage = JSON.parse(robot.brain.get brainloc) or {}
    ekvs = []
    ekvs.push "#{k}=#{v}" for k,v of localstorage
    environment = ekvs.join " "

    cmdline = "cd #{basepath}/#{projname}; #{environment} terraform #{action} -input=false -no-color"
    msg.send {room: msg.message.user.name}, "```\n#{cmdline}\n```"
    exec cmdline, (error, stdout, stderr) ->
      if stderr
        msg.send {room: msg.message.user.name}, "stderr:\n```\n#{stderr}\n```"
      else if error
        msg.send {room: msg.message.user.name}, "error:\n```\n#{error}\n```"
      if stdout
        if stdout.length < 1024
          return msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"
        else unless verbose
          return msg.send {room: msg.message.user.name}, "```\n#{line}\n```" if line.match /^Plan: / for line in stdout.split "\n"
        out = []
        waitms = 200
        textchunk = ''
        for line in stdout.split "\n"
          if line.match /^(?:\+\s|Plan: )/
            textchunk = out.join "\n"
            sendqueue.push { msg: msg, out: "```\n#{textchunk}\n```" }
            setTimeout servicequeue, waitms
            waitms = waitms + 200
            out = []
          out.push line
        textchunk = out.join "\n"
        sendqueue.push { msg: msg, out: "```\n#{textchunk}\n```" }
        setTimeout servicequeue, waitms

  robot.respond /tf env ([^\s]+) set ([^\s]+)=(.+)$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    projname = msg.match[1].replace /\//, "_"
    ekey = msg.match[2]
    evalue = msg.match[3]

    unless fs.existsSync("#{basepath}/#{projname}")
      return msg.send {room: msg.message.user.name}, "Invalid project name: `#{projname}`"

    brainloc = "hubot-tf_#{projname}"
    localstorage = JSON.parse(robot.brain.get brainloc) or {}
    localstorage[ekey] = evalue
    robot.brain.set brainloc, JSON.stringify(localstorage)
    robot.brain.save()

    return msg.send {room: msg.message.user.name}, "`#{projname}` env set: `#{ekey}` = `#{evalue}`"

  robot.respond /tf env ([^\s]+) unset ([^\s]+)$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    projname = msg.match[1].replace /\//, "_"
    ekey = msg.match[2]

    unless fs.existsSync("#{basepath}/#{projname}")
      return msg.send {room: msg.message.user.name}, "Invalid project name: `#{projname}`"

    brainloc = "hubot-tf_#{projname}"
    localstorage = JSON.parse(robot.brain.get brainloc) or {}
    delete localstorage[ekey]
    robot.brain.set brainloc, JSON.stringify(localstorage)
    robot.brain.save()

    return msg.send {room: msg.message.user.name}, "`#{projname}` env `#{ekey}` unset."

  robot.respond /tf env ([^\s]+)(?:\slist)?$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    projname = msg.match[1].replace /\//, "_"

    unless fs.existsSync("#{basepath}/#{projname}")
      return msg.send {room: msg.message.user.name}, "Invalid project name: `#{projname}`"

    brainloc = "hubot-tf_#{projname}"
    localstorage = JSON.parse(robot.brain.get brainloc) or {}

    ekvs = [ "`#{projname}` env:" ]
    ekvs.push "  `#{k}` = `#{v}`" for k,v of localstorage
    ekvs = [ "No environment variables for `#{projname}`." ] unless ekvs.length > 1
    return msg.send {room: msg.message.user.name}, ekvs.join "\n"
