package main

import (
	. "github.com/smartystreets/goconvey/convey"
	"net/http"
	"net/http/httptest"
	"testing"
)

// func TestAddObservationHttp(t *testing.T) {
// 	req, _ := http.NewRequest("POST", "/", nil)
// 	req.Header.Set("X-API-SESSION", "00TK6wuwwj1DmVDtn8mmveDMVYKxAJKLVdghTynDXBd62wDqGUGlAmEykcnaaO66")
// 	res := httptest.NewRecorder()
// 	Convey("Should add observation", t, func() {
// 		obs := ObservationComment{}
// 		obs.DiscoveryId = "663"
// 		obs.Comment = "test comment"
// 		obs.X = "0"
// 		obs.Y = "0"
// 		result := AddObservationHttp(res, req, obs)
// 		So(result, ShouldEqual, "")
// 	})
// }
// }

func TestGetObservationsHttp(t *testing.T) {
	req, _ := http.NewRequest("GET", "/", nil)
	req.Header.Set("X-API-SESSION", "00TK6wuwwj1DmVDtn8mmveDMVYKxAJKLVdghTynDXBd62wDqGUGlAmEykcnaaO66")
	res := httptest.NewRecorder()
	Convey("Should get observations", t, func() {
		params := map[string]string{}
		params["did"] = "592"
		result := GetObservationsHttp(res, req, params)
		So(result, ShouldNotBeNil)
	})
}

func TestGetRecentObservationsHttp(t *testing.T) {
	req, _ := http.NewRequest("GET", "/", nil)
	req.Header.Set("X-API-SESSION", "00TK6wuwwj1DmVDtn8mmveDMVYKxAJKLVdghTynDXBd62wDqGUGlAmEykcnaaO66")
	res := httptest.NewRecorder()

	Convey("Should get observations", t, func() {
		result := GetRecentObservationsHttp(res, req)
		So(result, ShouldNotBeNil)
	})
}

func TestFlagObservationHttp(t *testing.T) {
	req, _ := http.NewRequest("GET", "/", nil)
	req.Header.Set("X-API-SESSION", "00TK6wuwwj1DmVDtn8mmveDMVYKxAJKLVdghTynDXBd62wDqGUGlAmEykcnaaO66")
	res := httptest.NewRecorder()
	params := map[string]string{}
	params["id"] = "755"

	Convey("Should get observations", t, func() {
		result := FlagObservationHttp(res, req, params)
		So(result, ShouldNotBeNil)
	})
}
