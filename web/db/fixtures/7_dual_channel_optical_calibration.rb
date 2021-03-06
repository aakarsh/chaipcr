experiment_definition = ExperimentDefinition.seed(:guid) do |s|
  s.guid = "dual_channel_optical_cal"
  s.experiment_type = ExperimentDefinition::TYPE_CALIBRATION
  s.protocol_params ={lid_temperature:110, stages:[
   {stage:{stage_type:"holding",steps:[
     {step:{name:"Warm Up",temperature:65,hold_time:120,collect_data:false}},
     {step:{name:"Water",temperature:65,hold_time:20,collect_data:true}},
     {step:{name:"Swap",temperature:65,hold_time:1,pause:true}},
     {step:{name:"FAM",temperature:65,hold_time:20,collect_data:true}},
     {step:{name:"Swap",temperature:65,hold_time:1,pause:true}},
     {step:{name:"HEX",temperature:65,hold_time:20,collect_data:true}}
   ]}}]}
end

# set the protocol lid temperature to 110
protocol = Protocol.seed(:experiment_definition_id) do |s|
  s.lid_temperature = 110
  s.experiment_definition_id = experiment_definition[0].id
end

# In a previous version of this seed, there was an extra Swap step inserted between "Warm Up" and 
# "Water". This has since been removed from the seed, and the below removes it on previously seeded
# devices
steps = Step.where("name=?  AND stage_id=?", "Swap", protocol[0].stages[0].id)
if steps.length == 3
  steps[0].destroy
end


