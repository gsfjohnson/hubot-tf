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

  robot.respond /tf create key$/i, (msg) ->
    msg.send {room: msg.message.user.name}, "Creating key for #{msg.message.user.name}..."

    fn = msg.message.user.name
    fn.replace /\//, "_"
    fp = basepath + "/" + fn

    exec "ssh-keygen -f #{fp} -b 1024 -C tf -N ''", (error, stdout, stderr) ->
      #msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"
      pubkey = fs.readFileSync("#{fp}.pub", 'utf-8').toString()
      msg.send {room: msg.message.user.name}, "Public key: \n```\n#{pubkey}\n```"

  robot.respond /tf show key$/i, (msg) ->
    fn = msg.message.user.name
    fn.replace /\//, "_"
    fp = basepath + "/" + fn

    if ! fs.accessSync("#{fp}.pub", fs.F_OK|fs.R_OK)
      return msg.send {room: msg.message.user.name}, "No key on file!  Create one."

    pubkey = fs.readFileSync("#{fp}.pub", 'utf-8').toString()
    return msg.send {room: msg.message.user.name}, "Public key: \n```\n#{pubkey}\n```"
