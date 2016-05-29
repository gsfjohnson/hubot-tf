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
    fn = msg.message.user.name
    fn.replace /\//, "_"
    fp = basepath + "/" + fn

    if fs.existsSync("#{fp}.pub")
      return msg.send {room: msg.message.user.name}, "Key exists!  Destroy it, then try this again?"

    exec "ssh-keygen -f #{fp} -b 1024 -C hubot-tf -N ''", (error, stdout, stderr) ->
      #msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"
      pubkey = fs.readFileSync("#{fp}.pub", 'utf-8').toString()
      msg.send {room: msg.message.user.name}, "```\n#{pubkey}\n```"

  robot.respond /tf show key$/i, (msg) ->
    fn = msg.message.user.name
    fn.replace /\//, "_"
    fp = basepath + "/" + fn

    if ! fs.existsSync("#{fp}.pub")
      return msg.send {room: msg.message.user.name}, "No key on file!  Create one first, eh?"

    pubkey = fs.readFileSync("#{fp}.pub", 'utf-8').toString()
    return msg.send {room: msg.message.user.name}, "```\n#{pubkey}\n```"

  robot.respond /tf destroy key$/i, (msg) ->
    fn = msg.message.user.name
    fn.replace /\//, "_"
    fp = basepath + "/" + fn

    if ! fs.existsSync("#{fp}.pub")
      return msg.send {room: msg.message.user.name}, "No key on file!  Create one first, eh?"

    fs.unlinkSync("#{fp}")
    fs.unlinkSync("#{fp}.pub")
    return msg.send {room: msg.message.user.name}, "Key destroyed!"
