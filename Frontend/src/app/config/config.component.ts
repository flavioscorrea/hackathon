import { Component, OnInit } from '@angular/core';
import { PoCheckboxGroupOption } from '@po-ui/ng-components';
import { PoMenuItem } from '@po-ui/ng-components';
import { ConfigService } from 'src/core/config/config.service';

@Component({
  selector: 'app-config',
  templateUrl: './config.component.html',
  styleUrls: ['./config.component.css']
})
export class ConfigComponent implements OnInit {
  urlendpoint: string;
  pathendpoint: string;
  idacesso: string;
  domacesso: string;
  userendpoint: string;
  senhaendpoint: string;
  pathdevice: string;
  pathclockin: string;
  nomeorg: string;
  codtoken: string;
  properties: Array<string>;

  public readonly propertiesOptions: Array<PoCheckboxGroupOption> = [
    { value: 'reproc', label: 'Reprocessar NSR' }
  ];

  constructor(
    private configService: ConfigService,
  ) { }

  ngOnInit() {
    this.GetConfig();
  }

  restore(lMsg) {
    this.urlendpoint = undefined;
    this.pathendpoint = undefined;
    this.idacesso = undefined;
    this.domacesso = undefined;
    this.userendpoint = undefined;
    this.senhaendpoint = undefined;
    this.pathdevice = undefined;
    this.pathclockin = undefined;
    this.nomeorg = undefined;
    this.codtoken = undefined;
    this.properties = [];
    if(lMsg){
      alert('abriu!!!');
    }else{
      alert('Só Jesus salva!!!')
    }
  }
  private async GetConfig() {

    const { ActiveIntegration } = await this.configService
      .get()
      .toPromise();

    
    this.urlendpoint = ActiveIntegration;
    this.pathendpoint = undefined;
    this.idacesso = undefined;
    this.domacesso = undefined;
    this.userendpoint = undefined;
    this.senhaendpoint = undefined;
    this.pathdevice = undefined;
    this.pathclockin = undefined;
    this.nomeorg = undefined;
    this.codtoken = undefined;
    this.properties = [];
    
  }
}
