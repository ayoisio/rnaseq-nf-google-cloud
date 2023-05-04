import functions_framework
import json
import requests


def convert_transcript_id_to_amino_acid_sequence(ensembl_id):

  server = "https://rest.ensembl.org"
  ext = f"/sequence/id/{ensembl_id}?type=protein"

  r = requests.get(server + ext, headers={"Content-Type": "text/plain"})

  if not r.ok:
    return None
  
  return r.text


@functions_framework.http
def make_inference(request):
  
  calls = request.get_json()['calls']
  replies = []

  for call in calls:
    ensembl_id = call[0]

    if not ensembl_id:
      replies.append(None)
      continue

    ensembl_id = ensembl_id.split(".")[0]
    output = convert_transcript_id_to_amino_acid_sequence(ensembl_id)
    replies.append(output)

  return json.dumps({'replies': replies})
