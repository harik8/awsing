#!/usr/bin/env python3
import os
import aws_cdk as cdk

from cdk.s3_stack import S3Stack
from dotenv import load_dotenv
import os

load_dotenv()

app = cdk.App()

# S3Stack(app, "h-tofu-state",
#   env=cdk.Environment(account=os.getenv('AWS_ACCOUNT_ID'), region=os.getenv('AWS_REGION')),
# )

# S3Stack(app, f"{os.getenv('TOFU_WORKSPACE')}-tofu-state",
#   env=cdk.Environment(account=os.getenv('AWS_ACCOUNT_ID'), region=os.getenv('AWS_REGION')),
# )

S3Stack(app, f"{os.getenv('OPENTOFU_WORKSPACE')}-opentofu-backend",
  env=cdk.Environment(account=os.getenv('AWS_ACCOUNT_ID'), region=os.getenv('AWS_REGION')),
)

app.synth()
