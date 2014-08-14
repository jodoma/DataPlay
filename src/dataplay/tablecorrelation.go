package main

import (
	"encoding/json"
	"math"
	"time"
)

type cmeth int

const ( //go version of enum
	P cmeth = iota
	S
	V
)

type CorrelationData struct {
	Method string    `json:"method"`
	Chart  string    `json:"type, omitempty"`
	Table1 TableData `json:"table1"`
	Table2 TableData `json:"table2"`
	Table3 TableData `json:"table3, omitempty"`
}

type TableData struct {
	ChartType string  `json:"type, omitempty"`
	Title     string  `json:"title"`
	Desc      string  `json:"desc"`
	LabelX    string  `json:"xLabel"`
	LabelY    string  `json:"yLabel,omitempty"`
	LabelZ    string  `json:"zLabel,omitempty"`
	Values    []XYVal `json:"values"`
}

type XYVal struct {
	X     string `json:"x"`
	Y     string `json:"y"`
	Z     string `json:"z,omitempty"`
	Xtype string `json:"-"`
	Ytype string `json:"-"`
	Ztype string `json:"-"`
}

type DateVal struct {
	Date  time.Time
	Value float64
}

type FromTo struct {
	From time.Time
	To   time.Time
}

// Take in table name and a threshold for the looping and attempt to get correlated tables through a variety of correlation methods
// Use 3:1:1 for Spurious to Pearson and Visual as Spurious less likely to find correlations
func GenerateCorrelations(tableName string, searchDepth int) {
	m := make(map[string]string)
	m["table1"] = tableName
	c := P

	///Main loop to generate/check for correlations based on input table
	for i := 0; i < searchDepth; i++ {
		r := i % 5

		if r == 0 {
			c = P
		} else if r == 1 {
			c = V
		} else {
			c = S
		}
		AttemptCorrelation(m, c)
	}
}

// Take in table name and a correlation type, then get some random apt columns from it and generate more random tables and columns and check for any  pre-existing correlations on that combination.
// If a correlation for the generated tables combination doesn't exist, attempt to calculate a new correlation coefficient and if one is generated save the new correlation.
func AttemptCorrelation(m map[string]string, c cmeth) {
	cor := Correlation{}
	var jsonData []string
	cd := new(CorrelationData)
	nameChk := GetRandomNameMap(m, c)

	if nameChk { // if all table and columns names are present in name map
		if c == P {
			err := DB.Model(&cor).Where("tbl1 = ?", m["table1"]).Where("col1 = ?", m["valCol1"]).Where("tbl2 = ?", m["table2"]).Where("col2 = ?", m["valCol2"]).Where("method = ?", "Pearson").Pluck("json", &jsonData).Error
			check(err)
		} else if c == S {
			err := DB.Model(&cor).Where("tbl1 = ?", m["table1"]).Where("col1 = ?", m["valCol1"]).Where("tbl2 = ?", m["table2"]).Where("col2 = ?", m["valCol2"]).Where("tbl3 = ?", m["table3"]).Where("col3 = ?", m["valCol3"]).Where("method = ?", "Spurious").Pluck("json", &jsonData).Error
			check(err)
		} else if c == V {
			err := DB.Model(&cor).Where("tbl1 = ?", m["table1"]).Where("col1 = ?", m["valCol1"]).Where("tbl2 = ?", m["table2"]).Where("col2 = ?", m["valCol2"]).Where("method = ?", "Visual").Pluck("json", &jsonData).Error
			check(err)
		}

		if jsonData == nil { // if no correlation exists then generate one
			cf := CalculateCoefficient(m, c, cd)
			if cf != 0 { //Save the correlation if one is generated
				SaveCorrelation(m, c, cf, cd)
			}
		}
	}
}

// Determine if two sets of dates overlap - X values are referenced so they can be altered in place and passed back again when used with Spurious correlation which covers the intersect between three data sets
func GetIntersect(pFromX *time.Time, pToX *time.Time, pRngX *int, fromY time.Time, toY time.Time, rngY int) []FromTo {
	var bucketRange []FromTo
	fromX, toX, rngX := *pFromX, *pToX, *pRngX

	if rngX <= rngY && (fromX == fromY && toX == toY || fromX.After(fromY) && toX.Before(toY)) {
		bucketRange = CreateBuckets(fromX, toX, rngX)
	} else if rngY < rngX && fromY.After(fromX) && toY.Before(toX) {
		bucketRange = CreateBuckets(fromY, toY, rngY)
		*pFromX = fromY
		*pToX = toY
		*pRngX = rngY
	} else if fromX.Before(fromY) && toX.Before(fromY) || fromX.After(toY) && toX.After(toY) {
		return nil
	} else if fromX.Before(fromY) {
		rngYX := dayNum(toX) - dayNum(fromY)
		bucketRange = CreateBuckets(fromY, toX, rngYX)
		*pFromX = fromY
		*pRngX = rngYX
	} else {
		rngXY := dayNum(toY) - dayNum(fromX)
		bucketRange = CreateBuckets(fromX, toY, rngXY)
		*pToX = toY
		*pRngX = rngXY
	}

	return bucketRange
}

// Generate a correlation coefficient (if data allows), based on the requested correlation type
func CalculateCoefficient(m map[string]string, c cmeth, cd *CorrelationData) float64 {
	if len(m) == 0 {
		return 0.0
	}

	var bucketRange []FromTo
	var xBuckets, yBuckets, zBuckets []float64
	var cf float64
	x := ExtractDateVal(m["table1"], m["dateCol1"], m["valCol1"])
	y := ExtractDateVal(m["table2"], m["dateCol2"], m["valCol2"])
	fromX, toX, rngX := DetermineRange(x)
	fromY, toY, rngY := DetermineRange(y)

	if rngX == 0 || rngY == 0 {
		return 0
	}

	bucketRange = GetIntersect(&fromX, &toX, &rngX, fromY, toY, rngY)
	xBuckets = FillBuckets(x, bucketRange)
	yBuckets = FillBuckets(y, bucketRange)

	if c == P {
		cf = Pearson(xBuckets, yBuckets)
	} else if c == V {
		cf = Visual(xBuckets, yBuckets, bucketRange)
	} else if c == S {
		z := x
		x = y
		y = ExtractDateVal(m["table3"], m["dateCol3"], m["valCol3"])
		fromX, toX, rngX = DetermineRange(x)
		fromY, toY, rngY = DetermineRange(y)
		fromZ, toZ, rngZ := DetermineRange(z)

		if rngZ == 0 {
			return 0
		}

		GetIntersect(&fromX, &toX, &rngX, fromY, toY, rngY)
		bucketRange = GetIntersect(&fromX, &toX, &rngX, fromZ, toZ, rngZ)
		xBuckets = FillBuckets(x, bucketRange)
		yBuckets = FillBuckets(y, bucketRange)
		zBuckets = FillBuckets(z, bucketRange)
		cf = Spurious(xBuckets, yBuckets, zBuckets)
	} else {
		return 0
	}

	labels := LabelGen(bucketRange)
	n := len(bucketRange)
	values1 := make([]XYVal, n)
	values2 := make([]XYVal, n)
	values3 := make([]XYVal, n)

	for i, v := range labels {
		values1[i].X = v
		values2[i].X = v
		values1[i].Y = FloatToString(xBuckets[i])
		values2[i].Y = FloatToString(yBuckets[i])
		if c == S {
			values3[i].X = v
			values3[i].Y = FloatToString(zBuckets[i])
		}
	}

	(*cd).Table1.Values = values1
	(*cd).Table2.Values = values2

	if c == S {
		(*cd).Table3.Values = values3
	}

	return cf
}

//Create a json string containing all the data needed for generating a graph and then insert this and all the other correlation info into the correlations table
func SaveCorrelation(m map[string]string, c cmeth, cf float64, cd *CorrelationData) {
	ind1, ind2, ind3 := Index{}, Index{}, Index{}

	err1 := DB.Model(&ind1).Where("guid= ?", m["guid1"]).Find(&ind1).Error
	check(err1)

	err2 := DB.Model(&ind2).Where("guid= ?", m["guid2"]).Find(&ind2).Error
	check(err2)

	if c == S {
		err3 := DB.Model(&ind3).Where("guid= ?", m["guid3"]).Find(&ind3).Error
		check(err3)
	}

	(*cd).Method = m["method"]
	(*cd).Table1.Title = SanitizeString(ind1.Title)
	(*cd).Table2.Title = SanitizeString(ind2.Title)
	(*cd).Table1.Desc = SanitizeString(ind1.Notes)
	(*cd).Table2.Desc = SanitizeString(ind2.Notes)
	(*cd).Table1.LabelX = m["dateCol1"]
	(*cd).Table2.LabelX = m["dateCol2"]
	(*cd).Table1.LabelY = m["valCol1"]
	(*cd).Table2.LabelY = m["valCol2"]

	if c == S {
		(*cd).Table3.Title = SanitizeString(ind3.Title)
		(*cd).Table3.Desc = SanitizeString(ind3.Notes)
		(*cd).Table3.LabelX = m["dateCol3"]
		(*cd).Table3.LabelY = m["valCol3"]
	}

	jv, _ := json.Marshal(*cd)

	correlation := Correlation{
		Tbl1:    m["table1"],
		Col1:    m["valCol1"],
		Tbl2:    m["table2"],
		Col2:    m["valCol2"],
		Tbl3:    m["table3"],
		Col3:    m["valCol3"],
		Method:  m["method"],
		Coef:    cf,
		Json:    jv,
		Abscoef: math.Abs(cf), //absolute value for ranking as highly negative correlations are also interesting
	}

	err3 := DB.Save(&correlation).Error
	check(err3)
}
