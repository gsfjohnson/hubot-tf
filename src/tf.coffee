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

module.exports = (robot) ->

  robot.respond /auth help$/, (msg) ->
    cmds = []
    arr = [
      "tf create key - create rsa key, for git operations"
      "tf destroy key - erase key"
      "tf show key - display public key"
      "tf clone <repourl> <projectname>"
    ]

    for str in arr
      cmd = str.split " - "
      cmds.push "`#{cmd[0]}` - #{cmd[1]}"

    if replyInPrivate and msg.message?.user?.name?
      msg.reply 'replied to you in private!'
      robot.send {room: msg.message?.user?.name}, cmds.join "\n"
    else
      msg.reply cmds.join "\n"

  robot.respond /tf create key$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,'tf')
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing 'tf' role."

    #fn = msg.message.user.name
    #fn.replace /\//, "_"
    fp = basepath + "/hubot-tf"

    if fs.existsSync("#{fp}.pub")
      return msg.send {room: msg.message.user.name}, "Key exists!  Destroy it, then try this again?"

    exec "ssh-keygen -f #{fp} -b 1024 -C hubot-tf -N ''", (error, stdout, stderr) ->
      #msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"
      pubkey = fs.readFileSync("#{fp}.pub", 'utf-8').toString()
      msg.send {room: msg.message.user.name}, "```\n#{pubkey}\n```"

  robot.respond /tf show key$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,'tf')
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing 'tf' role."

    #fn = msg.message.user.name
    #fn.replace /\//, "_"
    fp = basepath + "/hubot-tf"

    if ! fs.existsSync("#{fp}.pub")
      return msg.send {room: msg.message.user.name}, "No key on file!  Create one first, eh?"

    pubkey = fs.readFileSync("#{fp}.pub", 'utf-8').toString()
    return msg.send {room: msg.message.user.name}, "```\n#{pubkey}\n```"

  robot.respond /tf destroy key$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,'tf')
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing 'tf' role."

    #fn = msg.message.user.name
    #fn.replace /\//, "_"
    fp = basepath + "/hubot-tf"

    if ! fs.existsSync("#{fp}.pub")
      return msg.send {room: msg.message.user.name}, "No key on file!  Create one first, eh?"

    fs.unlinkSync("#{fp}")
    fs.unlinkSync("#{fp}.pub")
    return msg.send {room: msg.message.user.name}, "Key destroyed!"

  robot.respond /tf clone ([^\s]+) ([^\s]+)$/i, (msg) ->
    unless robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,'tf')
      return msg.send {room: msg.message.user.name}, "Not authorized.  Missing 'tf' role."

    url = msg.match[1]
    projname = msg.match[2].replace /\//, "_"
    projpath = basepath + "/" + projname

    #fn = msg.message.user.name
    #fn.replace /\//, "_"
    fp = basepath + "/hubot-tf"

    exec "GIT_SSH_COMMAND='ssh -i #{fp} -F /dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' git clone #{url} #{projpath}", (error, stdout, stderr) ->
      if error
        msg.send {room: msg.message.user.name}, "Error: #{error}"
      if stderr
        msg.send {room: msg.message.user.name}, "stderr:\n```\n#{stderr}\n```"
      if stdout
        msg.send {room: msg.message.user.name}, "stdout:\n```\n#{stdout}\n```"
