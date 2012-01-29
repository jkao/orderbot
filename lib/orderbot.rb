require 'robut'

# TODO's:
# - Move configuration stuff to a separate file Robut::Plugin::Orderbot::Config
# - This includes the room name, API token, etc and place this in the .gitignore file
# - See if we can invite users 
# - See if we can have a history of places we've ordered
#
# A plugin that makes it easier to order food
class Robut::Plugin::Orderbot
  include Robut::Plugin

  class OrderBotException < Exception
  end

  # Initialize method, but we can't override initialize
  # We also can't seem to store these as class variables
  # since it appears we initialize per message
  def init_order_bot
    reply "Hi there, I'm #{connection.config.nick}! I am initializing for the first time, this may take a while..."

    # Can't seem to store these as class variables - so we'll place them in our internal hash
    store['orders_hash'] = {}
    store['notes_hash'] = {}
    store['users'] = {}
    store['ordered'] = false
    store['link'] = nil

    # Mutex to control access to the hash containing users/orders info
    store['nag_thread'] = nil

    # Flag it as initialized
    store['initialized'] = true
  end

  # Fetch symbols of current users via API
  def current_users
    connection.muc.roster.keys
  end

  # Main event handler
  def handle(time, sender, message)
    # There must be a better place to put an initialize method,
    # but initialize function has problems when overriden
    if !store['initialized']
      init_order_bot
    end

    words = words(message)
    phrase = words.join(" ")

    # Hey, the message is sent to me!
    if sent_to_me?(message)
      #reply "DEBUG: #{words.inspect}"

      # Respond based on some set of commands
      begin
        if is_new_order_request? words
          initialize_new_order(words)
        elsif is_clear_order_request? words
          clear_orders_and_notes(sender)
        elsif is_add_order_request? words
          add_order(sender, words)
        elsif is_add_note_request? words
          add_note(sender, words)
        elsif is_summary_request? words
          reply_summary
        elsif is_help_request? words
          help
        elsif is_nag_request? words
          turn_on_nagging
        elsif is_stop_nag_request? words
          reply "Alright... (okay)"
          turn_off_nagging
        elsif is_skip_request? words
          pass(sender)
        elsif is_where_request? words
          where
        elsif is_finish_request? words
          finish
        else
          reply_i_dont_know
        end
      rescue OrderBotException => e
        reply "Error: #{e.message}"
      end
    end
  end

  # ------------------------------------
  #
  # Set of methods that verify a command
  #
  # ------------------------------------

  # New batch of orders
  def is_new_order_request?(words)
    words.first =~ Config::NEW_ORDER_REGEX
  end

  # Clear your current order
  def is_clear_order_request?(words)
    words.first =~ Config::CLEAR_ORDER_REQUEST_REGEX
  end

  # Add an order
  def is_add_order_request?(words)
    words.first =~ Config::ADD_ORDER_REQUEST_REGEX
  end

  # Add a note about food
  def is_add_note_request?(words)
    words.first =~ Config::ADD_NOTE_REQUEST_REGEX
  end

  # Give a summary of what everyone has ordered
  def is_summary_request?(words)
    words.first =~ Config::SUMMARY_REQUEST_REGEX
  end

  # Get some help with commands
  def is_help_request?(words)
    words.first =~ Config::HELP_REQUEST_REGEX
  end

  # If you don't want to order lunch today
  def is_skip_request?(words)
    words.first =~ Config::SKIP_REQUEST_REGEX
  end

  # We are done ordering, stop the nagging!
  def is_finish_request?(words)
    words.first =~ Config::FINISH_REQUEST_REGEX
  end

  # Secret... call turn on nag function
  def is_nag_request?(words)
    words.first =~ Config::NAG_REQUEST_REGEX
  end

  # SECRET: Stop nagging!
  def is_stop_nag_request?(words)
    words.first =~ Config::STOP_NAG_REQUEST_REGEX
  end

  # Ask where we are eating
  def is_where_request?(words)
    words.first =~ Config::WHERE_REQUEST_REGEX
  end

  # ------------------------------------
  #
  # Set of methods that take in commands
  #
  # ------------------------------------

  def initialize_new_order(message)
    raise OrderBotException.new("Improper format: 'new [link]'") if message.nil? || message.length != 2

    # TODO: Verify message[1] is a link
    link = message[1]
    store['link'] = link

    # Mark that we haven't made any orders yet
    store['ordered'] = false

    # Throw out previous orders
    store['orders_hash'].clear
    store['notes_hash'].clear

    reply "Hey, @all Let's get ALL our orders in! (allthethings) Order from here: #{link}"

    # Start the nagging!!
    turn_on_nagging
  end

  # User places their order
  def add_order(sender, message)
    raise OrderBotException.new("Improper format: 'order [item]' (rageguy)") if message.nil? || message.length < 2

    order = message[1..-1].join(" ")
    add_to_hash(sender, order, store['orders_hash'])

    reply "Adding order #{order} from #{sender}... #{random_element(Config::YUMMY_REPLIES)}"
  end

  # User adds note about order
  def add_note(sender, message)
    raise OrderBotException.new("Improper format: 'note [item]' (rageguy)") if message.nil? || message.length < 2

    note = message[1..-1].join(" ")
    add_to_hash(sender, note, store['notes_hash'])

    reply "Adding note #{note} from #{sender}"
  end

  # Generic method to add stuff to a hash
  def add_to_hash(sender, value, hash)
    store['ordered'] = true

    hash[sender.intern] ||= []
    hash[sender.intern] << value
  end

  # User doesn't want to order
  def pass(sender)
    reply "Okay, if you say so... (foreveralone)"

    add_to_hash(sender, "Not ordering", store['orders_hash'])
  end

  # Tell users where we are ordering from
  def where
    if store['link'].nil?
      reply "I don't know... Y U GUYS NOT DECIDE YET (yuno)"
    else
      reply "We're eating from here: #{store['link']}"
    end
  end

  # Users can individually clear their orders/notes
  def clear_orders_and_notes(sender)
    reply "Clearing out your order, #{sender}"

    clear_orders(sender)
    clear_notes(sender)

    # No orders if nothing in this hash table
    store['ordered'] = false if store['orders_hash'].empty?
  end

  # User clears their orders
  def clear_orders(sender)
    store['orders_hash'].delete(sender.intern)
  end

  # User clears their notes
  def clear_notes(sender)
    store['notes_hash'].delete(sender.intern)
  end

  # Liz can call this method when we are done ordering
  # Alternatively, when nag filter runs and all users
  # all have orders then we are also done... perhaps this
  def finish
    reply "Yay we're done (yey)"
    reply_summary
    store['link'] = nil

    # Turn off nagging and monitoring
    turn_off_nagging
  end

  # Start a thread that runs the nag method
  def turn_on_nagging
    turn_off_nagging # Just in case we forgot about an earlier thread

    store['nag_thread'] = Thread.new {
      # Basically do an infinite nagging loop, til someone turns it off
      loop do
        # Do some nagging!
        nag
        sleep Config::NAG_TIME
      end
    }
  end

  def turn_off_nagging
    Thread.kill(store['nag_thread']) unless store['nag_thread'].nil?
  end

  # A method that checks against each user to see if they have orded or not
  def nag
    nagged = false
    nag_string = "Order something,"

    current_users.each do |user|
      if (store['orders_hash'][user.intern].nil? ||
          store['orders_hash'][user.intern].empty?) &&
            user != connection.config.nick
        nagged = true
        nag_string << " @#{user}"
      end
    end

    if nagged
      # If we need to nag people, send it out!
      reply nag_string
    else
      # Otherwise everyone has placed their orders in
      finish
    end
  end

  # ------------------------------------
  #
  # Set of methods that output messages
  #
  # ------------------------------------

  # Outputs a message of confusion (e.g. - bad command)
  def reply_i_dont_know
    reply "What? (disapproval) Call `@orderbot help` for help."
  end

  # Display all orders
  def reply_summary
    # TODO: might not want to use the << operator,
    # could use an append method
    # or something instead
    if store['ordered']
      order_string =
            "# ------------------------------------ #\n" +
            "#                                      #\n" +
            "#     HERE ARE THE ORDERS SO FAR       #\n" +
            "#                                      #\n" +
            "# ------------------------------------ #\n"

      # Print out contents of orders
      current_users.each do |user|
        if user != connection.config.nick
          orders = store['orders_hash'][user.intern]
          notes = store['notes_hash'][user.intern]

          if orders.nil? || orders.empty?
            order_string << "# #{user} didn't order!\n"
          else
            order_string << "# #{user}'s demands:\n"

            order_string << "# ORDER(S): \n"
            orders.each do |order|
              order_string << "# #{order}\n"
            end

            if !notes.nil?
              order_string << "# NOTE(S): \n"
              notes.each do |note|
                order_string << "# #{note}\n"
              end
            end
          end

          order_string << "# ------------------------------------ #\n"
        end
      end
      reply order_string
    else
      reply "No one made any orders yet (okay)"
    end
  end

  # Display help text
  def help
    reply [
      "# ------------------------------------ #",
      "#               Commands:",
      "# ------------------------------------ #",
      "  new|n [link] - create a new batch of orders (and start the nagging)",
      "  finish|f - manually finish this batch of orders (also turns off nagging)",
      "  add|a|o|ord|order [order] - add an order",
      "  note|no [message] - add a note about your order",
      "  summary|sum|s - prints out a summary of all orders",
      "  clear|c|cancel - remove your order (if you wanna start again)",
      "  sk|p|pass|skip|forgetme - if you're not ordering lunch, this is how you say it",
      "  h|help|usage - prints out this help",
      "  done|finish|d|f - finish off ordering",
      "  where|w - ask where we are ordering from?"
    ].join("\n")
  end

  private

  # Picks a random element from the array
  def random_element(array)
    return nil if array.nil? || array.empty?
    array[rand(array.length)]
  end
end

require File.expand_path('../config', __FILE__)

