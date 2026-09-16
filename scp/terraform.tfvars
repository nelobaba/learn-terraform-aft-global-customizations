allowed_regions                  = ["us-east-2", "us-east-1"] # keep home + backend region!
region_restriction_target_ou_ids = ["ou-k4qm-5vddq5re", "ou-k4qm-70byczxn"]  # add Production and sandbox
log_tampering_target_ids         = ["r-k4qm"]                              # root = all members
central_log_bucket_arns = [
  "arn:aws:s3:::aws-controltower-logs-220270546173-us-east-2",
  "arn:aws:s3:::aws-controltower-logs-220270546173-us-east-2/*",
]                     # fill at Step 6 (optional)