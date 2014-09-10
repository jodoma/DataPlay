package main

import (
	. "github.com/smartystreets/goconvey/convey"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRankValidations(t *testing.T) {
	Convey("Should return ranking", t, func() {
		result := RankValidations(23, 15)
		So(result, ShouldEqual, 0.44717586998695963)
	})
}

func TestValidateChartHttp(t *testing.T) {
	req, _ := http.NewRequest("GET", "/", nil)
	req.Header.Set("X-API-SESSION", "00TK6wuwwj1DmVDtn8mmveDMVYKxAJKLVdghTynDXBd62wDqGUGlAmEykcnaaO66")
	res := httptest.NewRecorder()
	Convey("Should validate chart", t, func() {
		params := map[string]string{}
		params["id"] = "114264"
		params["uid"] = "5"
		params["valflag"] = "false"
		result := ValidateChartHttp(res, req, params)
		So(result, ShouldEqual, "171")
	})
}

func TestValidateObservationHttp(t *testing.T) {
	req, _ := http.NewRequest("GET", "/", nil)
	req.Header.Set("X-API-SESSION", "00TK6wuwwj1DmVDtn8mmveDMVYKxAJKLVdghTynDXBd62wDqGUGlAmEykcnaaO66")
	res := httptest.NewRecorder()
	Convey("Should validate observation", t, func() {
		params := map[string]string{}
		params["id"] = "1"
		params["uid"] = "5"
		params["valflag"] = "false"
		result := ValidateObservationHttp(res, req, params)
		So(result, ShouldEqual, "Observation invalidated")
	})
}
