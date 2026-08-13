class Captain::PendingFollowUpAutomationFinder
  def initialize(assistant)
    @assistant = assistant
  end

  def perform
    return [] unless assistant.account.feature_enabled?('delayed_automations')
    return [] if connected_inbox_ids.empty?

    delayed_follow_up_rules.select do |rule|
      pending_status_condition?(rule) && follow_up_trigger?(rule) && sends_follow_up?(rule) && overlaps_connected_inbox?(rule)
    end
  end

  private

  attr_reader :assistant

  def connected_inbox_ids
    @connected_inbox_ids ||= assistant.inbox_ids
  end

  def delayed_follow_up_rules
    assistant.account.automation_rules.active
             .where(event_name: %w[conversation_updated message_created])
             .where.not(execution_delay: nil)
  end

  def follow_up_trigger?(rule)
    return true if rule.event_name == 'conversation_updated'

    equal_to_condition?(rule, 'message_type', 'outgoing') && equal_to_condition?(rule, 'private_note', false)
  end

  def pending_status_condition?(rule)
    condition = condition_for(rule, 'status')
    condition&.dig('filter_operator') == 'equal_to' && Array(condition['values']).include?('pending')
  end

  def sends_follow_up?(rule)
    rule.actions.any? { |action| action['action_name'] == 'send_message' }
  end

  def equal_to_condition?(rule, attribute_key, value)
    condition = condition_for(rule, attribute_key)
    condition&.dig('filter_operator') == 'equal_to' && Array(condition['values']).include?(value)
  end

  def overlaps_connected_inbox?(rule)
    condition = condition_for(rule, 'inbox_id')
    return true if condition.blank?
    return false unless condition['filter_operator'] == 'equal_to'

    Array(condition['values']).map(&:to_i).intersect?(connected_inbox_ids)
  end

  def condition_for(rule, attribute_key)
    rule.conditions.find { |condition| condition['attribute_key'] == attribute_key }
  end
end
