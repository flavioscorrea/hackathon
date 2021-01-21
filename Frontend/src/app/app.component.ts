import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { PoMenuItem } from '@po-ui/ng-components';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {

  constructor( private router: Router ) { }

  readonly menus: Array<PoMenuItem> = [
    //{ label: 'Home', action: this.onClick.bind(this) }
    { label: 'Início', link: 'home' }, { label: 'Config', link: 'config' }
  ];

  private onClick() {
    alert('Clicked in menu item')
  }

  ngOnInit() {
    //this.restore();
  }

  restore() {
      //alert('Só Jesus salva!!!');
     // this.router.navigate([ '/config' ])
  }

}
