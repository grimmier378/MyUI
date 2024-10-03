return {
	['Channels'] = {
		[0] = {
			['enabled'] = true,
			['Echo'] = '/dgt',
			['MainEnable'] = true,
			['enableLinks'] = false,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1,
			['TabOrder'] = 5,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#scowls at you, ready to attack --#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.03251487016677856,
								[2] = 0.37174510955810547,
								[3] = 0.7767441868782038,
								[4] = 1,
							},
						},
					},
				},
				[2] = {
					['eventString'] = '#*#glares at you threateningly --#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.18917053937911985,
								[2] = 0.8418604731559749,
								[3] = 0.06656573712825774,
								[4] = 1,
							},
						},
					},
				},
				[3] = {
					['eventString'] = '#*#regards you indifferently --#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[4] = {
					['eventString'] = '#*#regards you as an ally --#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[5] = {
					['eventString'] = '#*#looks upon you warmly --#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[6] = {
					['eventString'] = '#*#glowers at you dubiously --#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.9627907276153559,
								[2] = 0.04030286520719527,
								[3] = 0.04030286520719527,
								[4] = 1,
							},
						},
					},
				},
				[7] = {
					['eventString'] = '#*#kindly considers you --#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[8] = {
					['eventString'] = '#*#looks your way apprehensively --#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[9] = {
					['eventString'] = '#*#judges you amiably --#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'Consider',
		},
		[1] = {
			['enabled'] = true,
			['Echo'] = '/tell',
			['MainEnable'] = true,
			['enableLinks'] = true,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1.3830000162124634,
			['TabOrder'] = 2,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#sent #*# a tell that said:#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.7083265781402588,
								[2] = 0.46413505077362055,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[2] = {
					['eventString'] = '#*#you have not received any tells#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[3] = {
					['eventString'] = '#*#tells you, \'#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0,
								[2] = 0,
								[3] = 0.852320671081543,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = 'NO2PT1',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^P3',
							['color'] = {
								[1] = 0.6024992465972896,
								[2] = 0.22478593885898585,
								[3] = 0.9029535651206968,
								[4] = 1,
							},
						},
					},
				},
				[4] = {
					['eventString'] = '#*#You told #1#,#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.5,
								[2] = 0.5,
								[3] = 0.5,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'Tells',
			['commandBuffer'] = '',
		},
		[2] = {
			['enabled'] = true,
			['Echo'] = '/say',
			['MainEnable'] = true,
			['enableLinks'] = false,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1.28600001335144,
			['TabOrder'] = 15,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#You have gained #*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = 'experience',
							['color'] = {
								[1] = 1,
								[2] = 0.9620252847671509,
								[3] = 0,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = 'ability',
							['color'] = {
								[1] = 0.9255813956260679,
								[2] = 0.4208316802978514,
								[3] = 0.13345590233802793,
								[4] = 1,
							},
						},
					},
				},
				[2] = {
					['eventString'] = '#*# gained #*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 0,
								[3] = 0,
								[4] = 0,
							},
						},
						[1] = {
							['filterString'] = 'M3',
							['color'] = {
								[1] = 0.09478676319122312,
								[2] = 1,
								[3] = 0,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = 'GP1',
							['color'] = {
								[1] = 0,
								[2] = 0.5316455364227295,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'Exp AA pts',
			['commandBuffer'] = '',
		},
		[3] = {
			['enabled'] = true,
			['Echo'] = '/say',
			['MainEnable'] = true,
			['commandBuffer'] = '',
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1,
			['TabOrder'] = 12,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#MQ2LinkDB#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.8429319262504578,
								[2] = 0.8299925327301021,
								[3] = 0.34864720702171326,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = 'links in database',
							['color'] = {
								[1] = 0.8758199214935303,
								[2] = 0.8795811533927912,
								[3] = 0.16117979586124415,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = 'Scanning incoming chat for item links',
							['color'] = {
								[1] = 0.3519820868968962,
								[2] = 0.9581151604652405,
								[3] = 0.22071760892868042,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = 'Syntax',
							['color'] = {
								[1] = 0.9214659929275513,
								[2] = 0.6383149027824402,
								[3] = 0.3521833121776581,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = 'Not scanning incoming chat',
							['color'] = {
								[1] = 0.9162303805351254,
								[2] = 0.30221211910247775,
								[3] = 0.30221211910247775,
								[4] = 1,
							},
						},
						[5] = {
							['filterString'] = 'Will NOT scan incoming chat for item links',
							['color'] = {
								[1] = 0.9476439952850342,
								[2] = 0.30761218070983887,
								[3] = 0.30761218070983887,
								[4] = 1,
							},
						},
						[6] = {
							['filterString'] = 'Fetching Items',
							['color'] = {
								[1] = 0.7880054712295529,
								[2] = 0.9424083828926082,
								[3] = 0.2565719187259673,
								[4] = 1,
							},
						},
					},
				},
				[2] = {
					['eventString'] = '#*#LootLink#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 0.9767441749572754,
								[3] = 0,
								[4] = 1,
							},
						},
					},
				},
				[3] = {
					['eventString'] = '#*#LinksDB#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[4] = {
					['eventString'] = '#*# looted a #*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0,
								[2] = 0.7355325818061829,
								[3] = 0.9302325248718262,
								[4] = 1,
							},
						},
					},
				},
			},
			['Name'] = 'Loot',
			['enableLinks'] = true,
		},
		[4] = {
			['enabled'] = false,
			['Echo'] = '/rsay',
			['MainEnable'] = true,
			['enableLinks'] = false,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1.4529999494552608,
			['TabOrder'] = 8,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#tell#*# raid, \'#*#\'#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.10673616081476212,
								[2] = 0.34685027599334717,
								[3] = 0.6824644804000849,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.5924170613288875,
								[2] = 0.5924170613288875,
								[3] = 0.5924170613288875,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = 'tells the raid,',
							['color'] = {
								[1] = 0.12603041529655457,
								[2] = 0.41042256355285645,
								[3] = 0.8578199148178101,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'Raid',
		},
		[5] = {
			['enabled'] = true,
			['Echo'] = '/dex ',
			['MainEnable'] = false,
			['enableLinks'] = false,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1.3350000381469727,
			['TabOrder'] = 9,
			['Events'] = {
				[1] = {
					['eventString'] = '#*# Heals #*# for #*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0,
								[2] = 0.8720378875732422,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[2] = {
					['eventString'] = '#*#crush#*#point#*# of damage#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0,
								[2] = 0,
								[3] = 0,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.9716539978981017,
								[2] = 0.5424406528472896,
								[3] = 0.9952606558799744,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 0.7721518874168396,
								[2] = 0.2215456962585449,
								[3] = 0.2215456962585449,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0.1052715703845024,
								[2] = 0.42347007989883423,
								[3] = 0.9240506291389461,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.3188607692718506,
								[2] = 0.8548290133476254,
								[3] = 0.8625592589378357,
								[4] = 1,
							},
						},
					},
				},
				[3] = {
					['eventString'] = '#*# healed #*# for #*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = 'GP1',
							['color'] = {
								[1] = 0,
								[2] = 0.6729857921600342,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[4] = {
					['eventString'] = '#*# kick#*#point#*# of damage#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 0,
								[3] = 0,
								[4] = 0,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.9725490212440491,
								[2] = 0.5411764979362488,
								[3] = 0.9960784316062924,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 0.8976744413375849,
								[2] = 0.34236884117126465,
								[3] = 0.34236884117126465,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0.7212910056114197,
								[2] = 0.43643292784690857,
								[3] = 0.8691983222961426,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.3176470696926117,
								[2] = 0.8549019694328307,
								[3] = 0.8627451062202454,
								[4] = 1,
							},
						},
					},
				},
				[5] = {
					['eventString'] = '#*# bite#*#point#*# of damage#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 0,
								[3] = 1,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 1,
								[2] = 0.3886256217956543,
								[3] = 0.3886256217956543,
								[4] = 1,
							},
						},
					},
				},
				[6] = {
					['eventString'] = '#*#non-melee#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.9789029359817505,
								[2] = 0.680678129196167,
								[3] = 0.21891078352928162,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0.9746835231781006,
								[2] = 0.40437859296798695,
								[3] = 0.06991400569677353,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.7843490242958069,
								[2] = 0.8530805706977841,
								[3] = 0,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 1,
								[2] = 0.14218008518218989,
								[3] = 0,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.3176470696926117,
								[2] = 0.8549019694328307,
								[3] = 0.8627451062202454,
								[4] = 1,
							},
						},
					},
				},
				[7] = {
					['eventString'] = '#*# bash#*#point#*# of damage#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.07594943046569823,
								[2] = 1,
								[3] = 0,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.9725490212440491,
								[2] = 0.5411764979362488,
								[3] = 0.9960784316062924,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0.28314730525016785,
								[2] = 0.3833853304386139,
								[3] = 0.9052132368087769,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 0.8909952640533444,
								[2] = 0.4307180941104889,
								[3] = 0.4307180941104889,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.3176470696926117,
								[2] = 0.8549019694328307,
								[3] = 0.8627451062202454,
								[4] = 1,
							},
						},
					},
				},
				[8] = {
					['eventString'] = '#*# hits#*#point#*# of damage#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0.867298603057861,
								[2] = 0.720706582069397,
								[3] = 0.14797510206699369,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 0.9336493015289307,
								[2] = 0.32744100689887995,
								[3] = 0.32744100689887995,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.3176470696926117,
								[2] = 0.8549019694328307,
								[3] = 0.8627451062202454,
								[4] = 1,
							},
						},
					},
				},
				[9] = {
					['eventString'] = '#*#You hit #*# for #*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.9725490212440491,
								[2] = 0.5411764979362488,
								[3] = 0.9960784316062924,
								[4] = 1,
							},
						},
					},
				},
				[10] = {
					['eventString'] = '#*#pierce#*#point#*# of damage#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0,
								[2] = 0,
								[3] = 0,
								[4] = 0,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.9725490212440491,
								[2] = 0.5411764979362488,
								[3] = 0.9960784316062924,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 0.9573459625244141,
								[2] = 0.3130657374858854,
								[3] = 0.3130657374858854,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0,
								[2] = 0.30331778526306147,
								[3] = 1,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.3176470696926117,
								[2] = 0.8549019694328307,
								[3] = 0.8627451062202454,
								[4] = 1,
							},
						},
					},
				},
				[11] = {
					['eventString'] = '#*#backstabs #*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 0.9738219976425171,
								[3] = 0,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 1,
								[2] = 0,
								[3] = 0,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 1,
								[2] = 0.9952606558799744,
								[3] = 0,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.6919431686401365,
								[2] = 1,
								[3] = 0,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.9497414231300353,
								[2] = 0.971563994884491,
								[3] = 0.05065027996897697,
								[4] = 1,
							},
						},
					},
				},
				[12] = {
					['eventString'] = '#*# but miss#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.9837154746055602,
								[2] = 0.8815165758132935,
								[3] = 1,
								[4] = 0,
							},
						},
						[1] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0.6540284156799312,
								[2] = 0.6540284156799312,
								[3] = 0.6540284156799312,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.6966824531555176,
								[2] = 0.6702679395675657,
								[3] = 0.6702679395675657,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.6540284156799312,
								[2] = 0.6385301351547239,
								[3] = 0.6385301351547239,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 0.5118483304977417,
								[2] = 0.5045708417892455,
								[3] = 0.5045708417892455,
								[4] = 1,
							},
						},
					},
				},
				[13] = {
					['eventString'] = '#*#slash#*#point#*# of damage#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 0,
								[4] = 0,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.9725490212440491,
								[2] = 0.5411764979362488,
								[3] = 0.9960784316062924,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0.19884634017944336,
								[2] = 0.584397971630096,
								[3] = 0.9240506291389461,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 0.9810426235198975,
								[2] = 0.30686643719673157,
								[3] = 0.30686643719673157,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.3176470696926117,
								[2] = 0.8549019694328307,
								[3] = 0.8627451062202454,
								[4] = 1,
							},
						},
					},
				},
				[14] = {
					['eventString'] = '#*#trike through#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0,
								[2] = 1,
								[3] = 0.48372077941894526,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'Combat',
			['commandBuffer'] = '',
		},
		[6] = {
			['enabled'] = true,
			['Echo'] = '/say',
			['MainEnable'] = true,
			['enableLinks'] = true,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1,
			['TabOrder'] = 1,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#say, \'#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 0,
								[3] = 1,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.649789035320282,
								[2] = 0.649789035320282,
								[3] = 0.649789035320282,
								[4] = 1,
							},
						},
					},
				},
				[2] = {
					['eventString'] = '#*# says, \'#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^P3',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'Say',
			['commandBuffer'] = '',
		},
		[7] = {
			['enabled'] = true,
			['Echo'] = '/shout',
			['MainEnable'] = true,
			['enableLinks'] = true,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1,
			['TabOrder'] = 6,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#shout#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 0.05485230684280395,
								[3] = 0.05485230684280395,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.09314748644828795,
								[2] = 0.9198312163352963,
								[3] = 0.5745076537132261,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = 'P3',
							['color'] = {
								[1] = 1,
								[2] = 0,
								[3] = 0,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'Shout',
		},
		[8] = {
			['enabled'] = false,
			['Echo'] = '/say',
			['MainEnable'] = true,
			['enableLinks'] = false,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1,
			['TabOrder'] = 4,
			['Events'] = {
				[1] = {
					['eventString'] = '#*# guild,#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.47604146599769587,
								[2] = 0.721518993377685,
								[3] = 0.1674411296844482,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = 'tells the guild,',
							['color'] = {
								[1] = 0.16003449261188502,
								[2] = 0.9662446975708008,
								[3] = 0.0937706008553505,
								[4] = 1,
							},
						},
					},
				},
			},
			['Name'] = 'Guild',
		},
		[9] = {
			['enabled'] = true,
			['Echo'] = '/dgae /lootutils',
			['MainEnable'] = false,
			['enableLinks'] = false,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1.3359999656677244,
			['TabOrder'] = 10,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#ASSASSINATE#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0,
								[2] = 1,
								[3] = 0.9004738330841059,
								[4] = 1,
							},
						},
					},
				},
				[2] = {
					['eventString'] = '#*#Finishing Blow#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.9351065754890442,
								[2] = 0.4303797483444214,
								[3] = 0,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^TK1',
							['color'] = {
								[1] = 0.126582384109497,
								[2] = 1,
								[3] = 0,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0,
								[2] = 0.5534468889236448,
								[3] = 0.7298578023910517,
								[4] = 1,
							},
						},
					},
				},
				[3] = {
					['eventString'] = '#*#crippling blow#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0.9810426235198975,
								[2] = 0.7704051733016968,
								[3] = 0.4184541702270508,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^M3',
							['color'] = {
								[1] = 0.4907994568347931,
								[2] = 0.9620853066444397,
								[3] = 0.0820736438035965,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.9810426235198975,
								[2] = 0.9546881318092344,
								[3] = 0.553289473056793,
								[4] = 1,
							},
						},
					},
				},
				[4] = {
					['eventString'] = '#*#xceptional#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0,
								[2] = 1,
								[3] = 0.8354430198669434,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.025316476821899404,
								[2] = 1,
								[3] = 0,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 0,
								[2] = 1,
								[3] = 0.701421737670898,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[5] = {
					['eventString'] = '#*#critical hit#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 0,
								[3] = 0,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 1,
								[2] = 0.9099526405334473,
								[3] = 0,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^M1',
							['color'] = {
								[1] = 1,
								[2] = 0.6337511539459229,
								[3] = 0.12322276830673218,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.971563994884491,
								[2] = 0.8587411642074585,
								[3] = 0.5387345552444457,
								[4] = 1,
							},
						},
					},
				},
				[6] = {
					['eventString'] = '#*#critical blast#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.624836444854736,
								[2] = 0.2936142385005951,
								[3] = 0.8151658773422239,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^GP1',
							['color'] = {
								[1] = 1,
								[2] = 0.48815166950225825,
								[3] = 0.9830194115638733,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = '^PT3',
							['color'] = {
								[1] = 0.8659861683845519,
								[2] = 0.5939893126487732,
								[3] = 0.971563994884491,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'Crits',
		},
		[10] = {
			['enabled'] = true,
			['Echo'] = '/ooc',
			['MainEnable'] = true,
			['enableLinks'] = true,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1.4459999799728394,
			['TabOrder'] = 3,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#SERVER MESSAGE#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.9814603328704834,
								[2] = 0.9860464930534363,
								[3] = 0,
								[4] = 1,
							},
						},
					},
				},
				[2] = {
					['eventString'] = '#*# out of character, \'#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.2025316208600998,
								[2] = 0.800000011920929,
								[3] = 0,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^You',
							['color'] = {
								[1] = 0.7819905281066895,
								[2] = 0.7819905281066895,
								[3] = 0.7819905281066895,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^Eris',
							['color'] = {
								[1] = 1,
								[2] = 0.17721521854400635,
								[3] = 0.6563053131103516,
								[4] = 1,
							},
						},
						[3] = {
							['filterString'] = 'out of character',
							['color'] = {
								[1] = 0.10126590728759766,
								[2] = 1,
								[3] = 0,
								[4] = 1,
							},
						},
						[4] = {
							['filterString'] = '^Dhaymion',
							['color'] = {
								[1] = 0,
								[2] = 0.9528796672821045,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'OOC',
			['commandBuffer'] = '',
		},
		[11] = {
			['enabled'] = true,
			['Echo'] = '/say',
			['MainEnable'] = true,
			['enableLinks'] = false,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1,
			['TabOrder'] = 17,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#Your faction standing with#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.8579133152961731,
								[2] = 0.8902953863143921,
								[3] = 0.03756518289446831,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '[-]%d+%.?$',
							['color'] = {
								[1] = 0.9156118035316464,
								[2] = 0.35875272750854487,
								[3] = 0.1699869781732559,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '%d+%.?$',
							['color'] = {
								[1] = 0.3502134680747986,
								[2] = 0.9071729779243466,
								[3] = 0.1071765348315239,
								[4] = 1,
							},
						},
					},
				},
			},
			['Name'] = 'Faction',
		},
		[9100] = {
			['enabled'] = true,
			['Echo'] = '/say',
			['MainEnable'] = false,
			['commandBuffer'] = '',
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1,
			['TabOrder'] = 14,
			['Events'] = {
				[1] = {
					['eventString'] = '#*# says#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.734883725643158,
								[2] = 0.5475102066993709,
								[3] = 0.24951866269111628,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = 'N3',
							['color'] = {
								[1] = 0.8465116024017334,
								[2] = 0.5565092563629146,
								[3] = 0.2637966573238373,
								[4] = 1,
							},
						},
					},
				},
				[2] = {
					['eventString'] = '#*#You have received an invaluable piece of information#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.8649864792823792,
								[2] = 0.9488372206687924,
								[3] = 0,
								[4] = 1,
							},
						},
					},
				},
				[3] = {
					['eventString'] = '#*# whispers#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.7864310741424555,
								[2] = 0.9581395387649534,
								[3] = 0.6194484233856199,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = 'N3',
							['color'] = {
								[1] = 0.7965580224990845,
								[2] = 0.8744186162948604,
								[3] = 0.5327852368354793,
								[4] = 1,
							},
						},
					},
				},
				[4] = {
					['eventString'] = '#*#Your Adventurer Stone glows#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.46813815832138056,
								[2] = 0.9627907276153559,
								[3] = 0.12538671493530268,
								[4] = 1,
							},
						},
					},
				},
				[5] = {
					['eventString'] = '#*# shouts#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.8325581550598145,
								[2] = 0.2942996323108672,
								[3] = 0.2942996323108672,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = 'N3',
							['color'] = {
								[1] = 0.8930232524871824,
								[2] = 0.3364413380622864,
								[3] = 0.3364413380622864,
								[4] = 1,
							},
						},
					},
				},
				[6] = {
					['eventString'] = '#*# tells you#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 0.6475920677185059,
								[2] = 0.32153597474098206,
								[3] = 0.7767441868782038,
								[4] = 1,
							},
						},
						[1] = {
							['filterString'] = '^N3',
							['color'] = {
								[1] = 0.8171334266662598,
								[2] = 0.5023255944252012,
								[3] = 1,
								[4] = 1,
							},
						},
						[2] = {
							['filterString'] = '^PT1',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
				[7] = {
					['eventString'] = '#*#You have additional information to uncover#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 0.7238037586212156,
								[3] = 0.0046511888504028286,
								[4] = 1,
							},
						},
					},
				},
			},
			['Name'] = 'NPC',
			['enableLinks'] = true,
		},
		[9000] = {
			['enabled'] = false,
			['Echo'] = '/say',
			['MainEnable'] = true,
			['enableLinks'] = false,
			['PopOut'] = false,
			['locked'] = false,
			['Scale'] = 1,
			['TabOrder'] = 16,
			['Events'] = {
				[1] = {
					['eventString'] = '#*#',
					['enabled'] = true,
					['Filters'] = {
						[0] = {
							['filterString'] = '',
							['color'] = {
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 1,
							},
						},
					},
				},
			},
			['look'] = false,
			['Name'] = 'Spam',
			['commandBuffer'] = '',
		},
	},
	['timeStamps'] = true,
	['doLinks'] = false,
	['locked'] = false,
	['doRefresh'] = false,
	['refreshLinkDB'] = 10,
	['LoadTheme'] = 'Default',
	['Scale'] = 1,
	['mainEcho'] = '/gu',
	['keyName'] = 'RightShift',
	['keyFocus'] = false,
}
