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

// or more concisely
sys = require('sys')
exec = require('child_process').exec;

module.exports = (robot) ->

  robot.respond /tf create key$/i, (msg) ->
    msg.send {room: msg.message.user.name}, "Creating key for #{msg.message.user.name}..."
    exec("ssh-keygen -f ~/#{msg.message.user.name}.key -b 1024 -C tf -N ''", function (error, stdout, stderr) {
      msg.send {room: msg.message.user.name}, "```\n#{stdout}\n```"
    });
