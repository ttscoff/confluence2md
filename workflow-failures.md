*Tip*

A `surrogateKey` cannot be reused for a new workflow launch until the original workflow instance has terminated (successfully completed or failed for some reason) and subsequent garbage collected (30 days after termination).

## Example: surrogateKey

*Tip*

New workflows can be launched with the same `singletonKey` value after the original workflow terminates.

## Example


|Time|Event|Outcome|
|:---|:---|:---|
|t0|`launch(wf1, singletonKey='foo')`|`wf1` launched|
|t1|`launch(wf2, singletonKey='foo')`|Return non-terminal workflow that is using the same `singletonKey`|
|t2|`wf1 completes`|`wf1` completes|
|t3|`launch(wf2, surrogateKey='foo')`|`wf2` launched|




For a complete list of parameters, see [Workflow service interfaces](https://bitbucket.oci.oraclecorp.com/projects/WOR/repos/wfaas-client/browse/workflow-service-spec/specs/workflow-service-interface.yaml).


<!--Source: /Users/ttscoff/Desktop/Code/confluence2md/test/Workflow-Failures_382931001.html-->
