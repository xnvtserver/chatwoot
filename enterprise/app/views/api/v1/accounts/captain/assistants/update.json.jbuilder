json.partial! 'api/v1/models/captain/assistant', formats: [:json], resource: @assistant
json.pending_follow_up_automations @pending_follow_up_automations do |automation|
  json.id automation.id
  json.name automation.name
  json.execution_delay automation.execution_delay
end
