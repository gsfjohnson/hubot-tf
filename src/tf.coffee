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
#   tf help - list commands
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

module.exports = (robot) ->

  robot.respond /tf help$/, (msg) ->
    cmds = []
    arr = [
      "#{tfName} create key - create rsa key, for git operations"
      "#{tfName} destroy key - erase key"
      "#{tfName} show key - display public key"
      "#{tfName} clone <repourl> <projectname>"
      "#{tfName} (plan|refresh|apply|get|destroy) <projectname> - tf operations"
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
        msg.send {room: msg.message.user.name}, "stdout:\n```\n#{stdout}\n```"

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

    exec "cd #{basepath}/#{projname}; terraform #{action} -no-color", (error, stdout, stderr) ->
      if stderr
        msg.send {room: msg.message.user.name}, "stderr:\n```\n#{stderr}\n```"
      else if error
        msg.send {room: msg.message.user.name}, "error:\n```\n#{error}\n```"
      if stdout
        msg.send {room: msg.message.user.name}, "stdout:\n```\n#{stdout}\n```"

  robot.respond /tf (plan|refresh|apply|destroy) ([^\s]+)$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,tfRole)
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing #{tfRole} role."

    action = msg.match[1]
    projname = msg.match[2].replace /\//, "_"

    exec "cd #{basepath}/#{projname}; terraform #{action} -input=false -no-color", (error, stdout, stderr) ->
      if stderr
        msg.send {room: msg.message.user.name}, "stderr:\n```\n#{stderr}\n```"
      else if error
        msg.send {room: msg.message.user.name}, "error:\n```\n#{error}\n```"
      if stdout
        msg.send {room: msg.message.user.name}, "stdout:\n```\n#{stdout}\n```"
