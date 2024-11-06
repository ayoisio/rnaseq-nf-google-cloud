import functions_framework
import json
import requests
from typing import Optional, List, Any
from flask import Request
from functions_framework import Response


def convert_transcript_id_to_amino_acid_sequence(ensembl_id: str) -> Optional[str]:
    """
    Retrieves the amino acid sequence for a given Ensembl transcript ID using the Ensembl REST API.

    Args:
        ensembl_id: Ensembl transcript identifier (e.g., 'ENST00000398417'). Version numbers 
            will be stripped automatically.

    Returns:
        Optional[str]: The amino acid sequence if found, None if the transcript has no 
            associated protein sequence or if the API request fails.

    Raises:
        requests.exceptions.RequestException: If the API request fails for network-related reasons
        requests.exceptions.HTTPError: If the Ensembl API returns a non-200 status code
    """
    server = "https://rest.ensembl.org"
    ext = f"/sequence/id/{ensembl_id}?type=protein"
    r = requests.get(server + ext, headers={"Content-Type": "text/plain"})
    if not r.ok:
        return None
    
    return r.text


@functions_framework.http
def make_inference(request: Request) -> Response:
    """
    Google Cloud Function that processes a batch of Ensembl transcript IDs and returns 
    their corresponding amino acid sequences.

    Args:
        request: HTTP request object containing a JSON payload with a 'calls' field.
            The 'calls' field should be a list of lists, where each inner list contains 
            a single Ensembl transcript ID as its first element.

    Returns:
        Response: JSON response containing a 'replies' field with a list of amino acid 
            sequences (or None values) corresponding to each input transcript ID.

    Example:
        Request JSON:
        {
            "calls": [
                ["ENST00000398417.1"],
                ["ENST00000257770.2"],
                [""]
            ]
        }

        Response JSON:
        {
            "replies": [
                "MAEGEITTFTALTEKFNLPPGNYKKPKLLYCSNGGHFLRILPDGTVDGTRDRSDQHIQLQLSAESVGEVYIKSTETGQYLAMDTDGLLYGSQTPNEECLFLERLEENHYNTYISKKHAEKNWFVGLKKNGSCKRGPRTHYGQKAILFLPLPV",
                "MDENQDRGSITHQNGPHHHHHHHNGHHHQLGPQHHPHLLHQQQQQQQQRHPGKIFDPKDISTNRSHESHGPPPAPGHALRYNNGAGQFPMHPGAGHHGVGHGAGHHRYGADGAHSDHYNRPAGVQNRSASHNLHHHHHHHHHHHGAGGGGGGPGAPRQVLPKRKLGIFTDIRGRPMNATKLMAVQLYLTPTQRKYFVDKKCADSNPAQLAELLRKKQSLTSGFKEILRYPTTQKLSSLQFDTTHPSPGRTNQLPPLLTSDAFPGANSEGGLPQVVPMVVPVGGGPLRLTQGSLTLNLIQTVNYLHNVVTVHLDVLLSQKSQSPHHHHHNGQGGDGPHPPTHQDYLKAWNNKHIILNTASIPGGQSPLHHQTMPLLTMPSPLVPVSGHGQIPSLTPVVLTTGHQAGSFLKLIQQTMLTVKSISQTNLITQLLIQQQQQQQQQQQQQQHLLLTQQQHQQQFLTFLNLLFQPQQFLLLSLMAPQIKHILTTNVAGKRFHLTTGPLLTSISNPSVLTNKPCRRKLKKKMSGTKRPKLPTKISKKTSVKK",
                null
            ]
        }
    """
    calls: List[List[str]] = request.get_json()['calls']
    replies: List[Optional[str]] = []
    
    for call in calls:
        ensembl_id = call[0]
        if not ensembl_id:
            replies.append(None)
            continue
            
        ensembl_id = ensembl_id.split(".")[0]  # Remove version number if present
        output = convert_transcript_id_to_amino_acid_sequence(ensembl_id)
        replies.append(output)
        
    return json.dumps({'replies': replies})
