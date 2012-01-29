class Robut::Plugin::Orderbot::Config
  # Time to pass by before robot starts reminding people to place their order
  NAG_TIME = 3

  # Orderbot's replies when you order something
  YUMMY_REPLIES = [
    "Yum",
    "Sounds good",
    "That's a little strange, but okay",
    "MMM...",
    "Awesome!",
    "Ew, that's disgusting, but alright if you say so...",
    "Good Choice!",
    "Awesome!",
    "Cool!"
  ]

  # Regex for orderbot's commands
  NEW_ORDER_REGEX = /^(new|n|newbatch)$/i
  CLEAR_ORDER_REQUEST_REGEX = /^(clear|c|cancel)$/i
  ADD_ORDER_REQUEST_REGEX = /^(order|add|a|o|ord)$/i
  ADD_NOTE_REQUEST_REGEX = /^(note|no)$/i
  SUMMARY_REQUEST_REGEX = /^(s|sum|summary)$/i
  HELP_REQUEST_REGEX = /^(h|help|usage|wtfhowdoiusethis)$/i
  SKIP_REQUEST_REGEX = /^(sk|p|skip|forgetme|pass)$/i
  FINISH_REQUEST_REGEX = /^(done|finish|f|completed|kablamo)$/i
  NAG_REQUEST_REGEX = /^(nag)$/i
  STOP_NAG_REQUEST_REGEX = /^(stopnag)$/i
  WHERE_REQUEST_REGEX = /^(where|w)$/i

end
