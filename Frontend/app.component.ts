import { Component, OnInit } from '@angular/core';

import { PoMenuItem } from '@po-ui/ng-components';

import { PoCheckboxGroupOption } from '@po-ui/ng-components';
import { CommonModule } from '@angular/common';
import { FormsModule }   from '@angular/forms';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent implements OnInit {
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

  ngOnInit() {
    this.restore(false);
  }

  restore(lsalva) {
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
    if(lsalva){
      alert('Só Jesus salva!!!');
    }
  }

  readonly menus: Array<PoMenuItem> = [
    { label: "Carga de marca\u00e7\u00f5es", action: this.onClick.bind(this) }
  ];

  private onClick() {
    alert('Stop the count!!!')
  }

}