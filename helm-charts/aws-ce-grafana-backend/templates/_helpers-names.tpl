{{- /*
    These helpers encapsulates logic on how we name resources. They also enable
    parent charts to reference these dynamic resource names.

    To avoid duplicating documentation, for more information, please see the the
    fullnameOverride entry the jupyterhub chart's configuration reference:
    https://z2jh.jupyter.org/en/latest/resources/reference.html#fullnameOverride
*/}}



{{- /*
    Utility templates
*/}}

{{- /*
    Renders to a prefix for the chart's resource names. This prefix is assumed to
    make the resource name cluster unique.
*/}}
{{- define "aws-ce-grafana-backend.fullname" -}}
    {{- /*
        We have implemented a trick to allow a parent chart depending on this
        chart to call these named templates.

        Caveats and notes:

            1. While parent charts can reference these, grandparent charts can't.
            2. Parent charts must not use an alias for this chart.
            3. There is no failsafe workaround to above due to
               https://github.com/helm/helm/issues/9214.
            4. .Chart is of its own type (*chart.Metadata) and needs to be casted
               using "toYaml | fromYaml" in order to be able to use normal helm
               template functions on it.
    */}}
    {{- $fullname_override := .Values.fullnameOverride }}
    {{- $name_override := .Values.nameOverride }}
    {{- if ne .Chart.Name "aws-ce-grafana-backend" }}
        {{- if .Values.jupyterhub }}
            {{- $fullname_override = .Values.jupyterhub.fullnameOverride }}
            {{- $name_override = .Values.jupyterhub.nameOverride }}
        {{- end }}
    {{- end }}

    {{- if eq (typeOf $fullname_override) "string" }}
        {{- $fullname_override }}
    {{- else }}
        {{- $name := $name_override | default .Chart.Name }}
        {{- if contains $name .Release.Name }}
            {{- .Release.Name }}
        {{- else }}
            {{- .Release.Name }}-{{ $name }}
        {{- end }}
    {{- end }}
{{- end }}

{{- /*
    Renders to a blank string or if the fullname template is truthy renders to it
    with an appended dash.
*/}}
{{- define "aws-ce-grafana-backend.fullname.dash" -}}
    {{- if (include "aws-ce-grafana-backend.fullname" .) }}
        {{- include "aws-ce-grafana-backend.fullname" . }}-
    {{- end }}
{{- end }}



{{- /*
    Namespaced resources
*/}}

{{- /* webserver resources' default name */}}
{{- define "aws-ce-grafana-backend.webserver.fullname" -}}
    {{- if (include "aws-ce-grafana-backend.fullname" .) }}
        {{- include "aws-ce-grafana-backend.fullname" . }}
    {{- else -}}
        aws-ce-grafana-backend
    {{- end }}
{{- end }}

{{- /* webserver's ServiceAccount name */}}
{{- define "aws-ce-grafana-backend.webserver.serviceaccount.fullname" -}}
    {{- if .Values.serviceAccount.create }}
        {{- .Values.serviceAccount.name | default (include "aws-ce-grafana-backend.webserver.fullname" .) }}
    {{- else }}
        {{- .Values.serviceAccount.name }}
    {{- end }}
{{- end }}

{{- /* webserver's Ingress name */}}
{{- define "aws-ce-grafana-backend.webserver.ingress.fullname" -}}
    {{- if (include "aws-ce-grafana-backend.fullname" .) }}
        {{- include "aws-ce-grafana-backend.fullname" . }}
    {{- else -}}
        aws-ce-grafana-backend
    {{- end }}
{{- end }}



{{- /*
    Cluster wide resources

    We enforce uniqueness of names for our cluster wide resources. We assume that
    the prefix from setting fullnameOverride to null or a string will be cluster
    unique.
*/}}

{{- /*
    We currently have no cluster wide resources, but if you add one below in the
    future, remove this comment and add an entry mimicking how the jupyterhub helm
    chart does it.
*/}}
